import NIOCore
import NIOExtras
import NIOPosix
import Testing

@testable import AMQP

enum AMQPNegotiationResult: Sendable {
    case success(NIOAsyncChannel<Frame, Frame>)
    case failure(String)
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
                return channel.pipeline
                    .addHandler(ByteToMessageHandler(ByteToMessageCoderHandler()))
                    .flatMap {
                        return channel.pipeline.addHandler(
                            MessageToByteHandler(ByteToMessageCoderHandler())
                        )
                    }
                    .flatMap {
                        return channel.pipeline.addHandler(
                            DebugOutboundEventsHandler { event, _ in print("\(event)") }
                        )
                    }
                    .flatMap {
                        return channel.pipeline.addHandler(
                            DebugInboundEventsHandler { event, _ in print("\(event)") }
                        )
                    }
                    .flatMap {
                        return channel.pipeline.addHandler(
                            AMQPNegotitionHandler(
                                negotiator: Spec.AMQPNegotiator(config: config, properties: props)
                            )
                        )
                    }
            }

        let channel = try? bootstrap.connect(host: configuration.host, port: configuration.port)
            .wait()

        guard let channel else {
            throw ConnectionError.unknown
        }

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
