import NIOCore
import NIOPosix

#if canImport(NIOExtras)
    import NIOExtras
#endif

final class Transport: Sendable {
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private let asyncNIOChannel: NIOAsyncChannel<Frame, Frame>

    init(
        host: String = "localhost",
        port: Int = 5672,
        negotiatorFactory: @escaping @Sendable () -> some AMQPNegotiatorProtocol
    ) async throws {
        // one event loop per connection
        eventLoopGroup = .init(numberOfThreads: 1)
        let negotiationComplete = eventLoopGroup.any().makePromise(of: Void.self)
        asyncNIOChannel = try await ClientBootstrap(group: eventLoopGroup)
            .connect(host: host, port: port) { channel in
                return channel.pipeline
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
                            AMQPNegotitionHandler(
                                negotiator: negotiatorFactory(),
                                done: negotiationComplete
                            )
                        )
                    }
                    .flatMapThrowing {
                        return try NIOAsyncChannel<Frame, Frame>(
                            wrappingChannelSynchronously: channel
                        )
                    }
            }
        try await negotiationComplete.futureResult.get()
    }

    deinit {
        try? asyncNIOChannel.channel.close().wait()
    }
}

extension Transport {
    typealias FrameHandler = @Sendable (any Frame) async throws -> Void
    /// Consume frames as they come from the server and call `handleInboundFrame` on each of them.
    ///
    /// - Throws: Any error that occurs during task execution.
    func execute(_ handler: @escaping FrameHandler) async throws {
        try await withThrowingTaskGroup { group in
            try await asyncNIOChannel.executeThenClose { inbound, _ in
                for try await frame in inbound {
                    group.addTask {
                        try await handler(frame)
                    }
                }
            }
        }
    }

    func send(frame: Frame) async throws {
        try await self.asyncNIOChannel.channel.writeAndFlush(frame)
    }
}
