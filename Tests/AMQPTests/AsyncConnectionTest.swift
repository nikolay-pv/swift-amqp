import NIOCore
import NIOPosix
import Testing

@testable import AMQP

enum AMQPNegotiationResult: Sendable {
    case success(NIOAsyncChannel<AMQPFrame, AMQPFrame>)
    case failure(String)
}

class AMQPNegotitionHandler: ChannelInboundHandler, RemovableChannelHandler {
    public typealias InboundIn = NIOAny
    public typealias OutboundOut = NIOAny

    private let completionHandler: (AMQPNegotiationResult, Channel) -> EventLoopFuture<Void>
    // private var stateMachine = TODO(@nikolay-pv):

    public init(
        completionHandler: @escaping (
            AMQPNegotiationResult,
            Channel
        ) -> EventLoopFuture<Void>
    ) {
        self.completionHandler = completionHandler
    }

    public func channelRegistered(context: ChannelHandlerContext) {
        let header = try! AMQPProtocolHeader.specHeader.asFrame()
        _ = context.writeAndFlush(NIOAny(ByteBuffer(bytes: header)))
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        print("Got data")
        print(data)
    }
}

public actor AsyncConnection {

    // MARK: - AMQP
    private(set) var configuration: AMQPConfiguration
    private var channel0: AMQPChannel
    // MARK: - NIO stack
    private var eventLoopGroup: MultiThreadedEventLoopGroup
    private var nioChannel: NIOAsyncChannel<AMQPFrame, AMQPFrame>

    // MARK: - init
    public init(with configuration: AMQPConfiguration = .default) async throws {
        self.configuration = configuration
        channel0 = AMQPChannel(id: 0)
        // TODO(@nikolay-pv): should be in config? What will higher number achieve here?
        eventLoopGroup = .init(numberOfThreads: 1)
        // .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
        let res =
            try await bootstrap
            .connect(
                host: configuration.host,
                port: configuration.port
            ) { channel in
                channel.eventLoop.makeCompletedFuture(
                    withResultOf: {
                        // 2.2.4 from AMQP spec
                        // TODO(@nikolay-pv): install the handler here to decode the frames
                        let handler = AMQPNegotiationHandler { _, channel in
                            // TODO(@nikolay-pv): setup the channel here on success
                            return channel.eventLoop.makeSucceededVoidFuture()
                        }
                        try! channel.pipeline.syncOperations.addHandler(handler)
                        let header = try! AMQPProtocolHeader.specHeader.asFrame()
                        channel.pipeline.syncOperations.writeAndFlush(
                            NIOAny(ByteBuffer(bytes: header)),
                            promise: nil
                        )
                        print("Sent header!")
                        // if socket closes here then it means misconfig or wrong header TODO: raise an exception?
                        // get Start method
                        // let buffer = channel.read()
                        // let start = try FrameDecoder.decode(AMQP.Start.self, from: buffer)
                        // send Start-Ok method with selected security mechanism
                        // repeat below two
                        // SASL, challenge-response model = get Secure method
                        // send Secure-Ok method
                        // get Tune method to set capabilities
                        // send Tune-Ok method
                        // get Open method with virtual host
                        // sent Open-Ok method
                        // ready!
                        // TODO(@nikolay-pv): add handlers
                        // done setting up hanlders

                        let asyncChannel = try NIOAsyncChannel(
                            wrappingChannelSynchronously: channel,
                            configuration: NIOAsyncChannel.Configuration(
                                inboundType: AMQPFrame.self,
                                outboundType: AMQPFrame.self
                            )
                        )
                        return AMQPNegotiationResult.success(asyncChannel)
                    })
            }

        switch res {
        case .success(let channel):
            print("Connected to broker!")
            nioChannel = channel
        case .failure(let error):
            throw AMQPConnectionError.handshakeFailed(reason: error)
        }
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
