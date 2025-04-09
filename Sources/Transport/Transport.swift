import NIOCore
import NIOPosix

#if canImport(NIOExtras)
    import NIOExtras
#endif

actor Transport {
    private var eventLoopGroup: MultiThreadedEventLoopGroup
    private var asyncNIOChannel: NIOAsyncChannel<Frame, Frame>

    init(
        host: String = "localhost",
        port: Int = 5672,
        _ negotiatorFactory: @escaping @Sendable () -> some AMQPNegotiatorProtocol
    ) async throws {
        // TODO(@nikolay-pv): should be in config? What will higher number achieve here?
        eventLoopGroup = .init(numberOfThreads: 1)
        asyncNIOChannel = try await ClientBootstrap(group: eventLoopGroup)
            .connect(host: host, port: port) { channel in
                channel.eventLoop
                    .makeCompletedFuture {
                        let res = channel.pipeline
                            .addHandler(ByteToMessageHandler(ByteToMessageCoderHandler()))
                            .flatMap {
                                return channel.pipeline.addHandler(
                                    MessageToByteHandler(ByteToMessageCoderHandler())
                                )
                            }
                            #if canImport(NIOExtras)
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
                            #endif
                            .flatMap {
                                return channel.pipeline.addHandler(
                                    AMQPNegotitionHandler(negotiator: negotiatorFactory())
                                )
                            }
                    }
                    .flatMapThrowing {
                        return try NIOAsyncChannel<Frame, Frame>(
                            wrappingChannelSynchronously: channel
                        )
                    }
            }
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }
}
