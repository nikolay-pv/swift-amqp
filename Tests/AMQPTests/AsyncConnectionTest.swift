import NIOCore
import NIOPosix
import Testing

@testable import AMQP

enum AMQPNegotiationResult: Sendable {
    case success(NIOAsyncChannel<ByteBuffer, ByteBuffer>)
    case failure(String)
}

class AMQPNegotiationHandler: ChannelInboundHandler, RemovableChannelHandler {
    public typealias InboundIn = NIOAny
    public typealias OutboundOut = NIOAny

    private let completionHandler: (AMQPNegotiationResult, Channel) -> EventLoopFuture<Void>
    // private var stateMachine = TODO

    public init( completionHandler: @escaping ( AMQPNegotiationResult,
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
    // MARK: - init
    public init(with configuration: AMQPConfiguration = .default) async throws {
        self.configuration = configuration
        channel0 = AMQPChannel(id: 0)
        // TODO: should be in config? What will higher number achieve here?
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
                        // TODO? install the handler here to decode the frames
                        let handler = AMQPNegotiationHandler() { _, channel in
                                // TODO
                                return channel.eventLoop.makeSucceededVoidFuture()
                            }
                        try! channel.pipeline.syncOperations.addHandler(handler)
                        let header = try! AMQPProtocolHeader.specHeader.asFrame()
                        channel.pipeline.syncOperations.writeAndFlush(NIOAny(ByteBuffer(bytes: header)), promise: nil)
                        print("Sent header!")
                        let asyncChannel = try NIOAsyncChannel(
                            wrappingChannelSynchronously: channel,
                            configuration: NIOAsyncChannel.Configuration(
                                inboundType: ByteBuffer.self,
                                outboundType: ByteBuffer.self
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

    private(set) var configuration: AMQPConfiguration
    private var eventLoopGroup: MultiThreadedEventLoopGroup
    private var nioChannel: NIOAsyncChannel<ByteBuffer, ByteBuffer>

    func start() async throws {
    }

    func close() {}
    func blockingClose() {}

    // MARK: - channel management
    private var channel0: AMQPChannel
}

@Test func exampleTest() async throws {
    let connection = try await AsyncConnection()
    sleep(10*60)
}
