import NIOCore
import NIOPosix
import Testing

@testable import AMQP

enum AMQPNegotiationResult: Sendable {
    case success(NIOAsyncChannel<Frame, Frame>)
    case failure(String)
}

class PrintAllHandler: ChannelDuplexHandler, RemovableChannelHandler {
    public typealias InboundOut = Any
    public typealias InboundIn = Any
    public typealias OutboundIn = Any
    public typealias OutboundOut = Any

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        print("Receive data: \(data)")
        context.fireChannelRead(data)
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        print("Send data: \(data)")
        context.write(data, promise: promise)
    }
}

enum Negotiator {
    static func decide(server: Int, client: Int) -> Int {
        if server == 0 || client == 0 {
            return max(server, client)
        }
        return min(server, client)
    }
}

class AMQPNegotitionHandler: ChannelInboundHandler, RemovableChannelHandler {
    public typealias InboundIn = Frame
    public typealias OutboundOut = Frame

    enum State {
        case waitingStart
        case waitingSecure
        case waitingTune
        case waitingOpenOk
        case complete
    }

    private var state: State = .waitingStart
    var config: AMQPConfiguration
    let properties: Spec.Table

    // since the channel initializer can be called multiple times, this method
    // doesn't handle the initial send of the Protocol header, it is done
    // outside
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data) as! MethodFrame
        switch state {
        case .waitingStart:
            // TODO: the below would need to be encapsulated somewhere
            // expected to get Connection.Start
            guard let method = frame.payload as? AMQP.Spec.Connection.Start else {
                context.fireErrorCaught(ConnectionError.Unknown)
                return
            }
            // check protocol versions mismatch
            if method.versionMajor != Spec.ProtocolLevel.MAJOR
                || method.versionMinor != Spec.ProtocolLevel.MINOR
            {
                context.fireErrorCaught(
                    ConnectionError.ProtocolVersionMismatch(
                        server: "\(method.versionMajor).\(method.versionMinor)",
                        client: "\(Spec.ProtocolLevel.MAJOR).\(Spec.ProtocolLevel.MINOR)"
                    )
                )
                return
            }
            // save server information somehow
            // self._set_server_information(method_frame)
            // self._send_connection_start_ok(*self._get_credentials(method_frame))
            if !method.mechanisms.contains(self.config.credentials.mechanim) {
                let msg = "\(self.config.credentials.mechanim) is not supported by the server"
                context.fireErrorCaught(ConnectionError.UnsupportedAuthMechanism(msg))
                return
            }
            // send Start-Ok method with selected security mechanism
            let response = AMQP.Spec.Connection.StartOk(
                // clientProperties: properties,
                clientProperties: ["product": .longstr("pika")],
                mechanism: self.config.credentials.mechanim,
                response: self.config.credentials.response
            )
            // TODO: improve this constructor...
            let startOkFrame = MethodFrame(
                channelId: 0,
                payload: response
            )
            // TODO: how to handle those promises in this context?
            context.writeAndFlush(wrapOutboundOut(startOkFrame))
                .whenSuccess {
                    // TODO: this can be .waitingSecure if the SSL is enabled
                    self.state = .waitingTune
                }
        case .waitingSecure:
            // TODO: implement secure
            // repeat below two
            // SASL, challenge-response model = get Secure method
            // send Secure-Ok method
            // then wait on Tune
            return
        case .waitingTune:
            guard let method = frame.payload as? AMQP.Spec.Connection.Tune else {
                context.fireErrorCaught(ConnectionError.Unknown)
                return
            }
            // picking correct values
            self.config.channelMax = Negotiator.decide(
                server: Int(method.channelMax),
                client: self.config.channelMax
            )
            self.config.frameMax = Negotiator.decide(
                server: Int(method.frameMax),
                client: self.config.frameMax
            )
            // TODO: setup hearbeat here
            let response = AMQP.Spec.Connection.TuneOk(
                channelMax: Int16(self.config.channelMax),
                frameMax: Int32(self.config.frameMax),
                heartbeat: 0
            )
            let frame = MethodFrame(
                channelId: 0,
                payload: response
            )
            // TODO: how to handle those promises in this context?
            let connectData = wrapOutboundOut(
                MethodFrame(
                    channelId: 0,
                    payload: Spec.Connection.Open()  // TODO: config?
                )
            )
            context.writeAndFlush(wrapOutboundOut(frame))
                .flatMap {
                    let data = connectData
                    return context.writeAndFlush(data)
                }
                .whenSuccess {
                    self.state = .waitingOpenOk
                }
        case .waitingOpenOk:
            guard let method = frame.payload as? AMQP.Spec.Connection.OpenOk else {
                context.fireErrorCaught(ConnectionError.Unknown)
                return
            }
            context.pipeline.removeHandler(self, promise: nil)
        case .complete:
            fatalError("should have been removed from the channel's pipeline")
        }
    }

    init(config: AMQPConfiguration, properties: Spec.Table) {
        self.config = config
        self.properties = properties
    }
}

public actor AsyncConnection {

    // MARK: - AMQP
    // connection configuration as supplied by the user
    private(set) var configuration: AMQPConfiguration
    // default channel used to communicate all the meta information
    private var channel0: AMQPChannel
    // client properties
    // TODO: consider giving ability to configure those -> maybe should be merged with configuration on init
    private var properties: Spec.Table = [
        "product": .longstr("swift-amqp"),
        "platform": .longstr("swift"),  // TODO: version here or something
        "capabilities": .table([
            "authentication_failure_close": .bool(true),
            "basic.nack": .bool(true),
            "connection.blocked": .bool(true),
            "consumer_cancel_notify": .bool(true),
            "publisher_confirms": .bool(true),
        ]),
        "information": .longstr("website here"),
        // TODO: "version":  of the library
    ]
    // MARK: - NIO stack
    private var bootstrap: ClientBootstrap
    private var eventLoopGroup: MultiThreadedEventLoopGroup
    // private var nioChannel: NIOAsyncChannel<AMQPFrame, AMQPFrame>
    private var nioChannel: Channel

    // MARK: - init
    public init(with configuration: AMQPConfiguration = .default) throws {
        self.configuration = configuration
        channel0 = AMQPChannel(id: 0)
        // TODO(@nikolay-pv): should be in config? What will higher number achieve here?
        eventLoopGroup = .init(numberOfThreads: 1)
        let config = configuration
        let props = properties
        bootstrap = ClientBootstrap(group: eventLoopGroup)
            // .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                return channel.pipeline.addHandler(ByteToMessageHandler(AMQPByteToMessageCoder()))
                    .flatMap {
                        return channel.pipeline.addHandler(
                            MessageToByteHandler(AMQPByteToMessageCoder())
                        )
                    }
                    .flatMap {
                        return channel.pipeline.addHandler(PrintAllHandler())
                    }
                    .flatMap {
                        return channel.pipeline.addHandler(
                            AMQPNegotitionHandler(config: config, properties: props)
                        )
                    }
            }

        let channel = try? bootstrap.connect(host: configuration.host, port: configuration.port)
            .wait()

        guard let channel else {
            throw ConnectionError.Unknown
        }

        let header: Frame = ProtocolHeaderFrame.specHeader
        try channel.writeAndFlush(header).wait()  // this will kick in negotiation

        nioChannel = channel
    }

    deinit {
        // blockingClose()
        try? eventLoopGroup.syncShutdownGracefully()
    }

    // MARK: - channel management
    func start() async throws {
    }

    func close() {}
    func blockingClose() {}
}

@Test func exampleTest() async throws {
    let connection = try await AsyncConnection()
    sleep(10 * 60)
}
