import AsyncAlgorithms
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix

#if canImport(NIOExtras)
    import NIOExtras
#endif

struct Transport: ~Copyable {
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private let asyncNIOChannel: NIOAsyncChannel<Frame, Frame>

    private let continuation: AsyncStream<Frame>.Continuation?
    private let clientFrames: AsyncStream<Frame>

    init(
        host: String = "localhost",
        port: Int = 5672,
        negotiatorFactory: @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol
    ) async throws {
        // one event loop per connection
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let negotiationComplete = eventLoopGroup.any().makePromise(of: Void.self)
        let asyncNIOChannel = try await ClientBootstrap(group: eventLoopGroup)
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
                    #endif  // canImport(NIOExtras)
                    .flatMap {
                        return channel.pipeline.addHandler(
                            AMQPNegotiationHandler(
                                negotiator: negotiatorFactory(),
                                done: negotiationComplete
                            ),
                            name: AMQPNegotiationHandler.handlerName
                        )
                    }
                    .flatMapThrowing {
                        return try NIOAsyncChannel<Frame, Frame>(
                            wrappingChannelSynchronously: channel
                        )
                    }
            }
        try await negotiationComplete.futureResult.get()
        self.eventLoopGroup = eventLoopGroup
        self.asyncNIOChannel = asyncNIOChannel
        var internalContinuation: AsyncStream<Frame>.Continuation?
        self.clientFrames = AsyncStream { continuation in
            internalContinuation = continuation
            // TODO: onTermination
        }
        self.continuation = internalContinuation
    }

    deinit {
        try? asyncNIOChannel.channel.close().wait()
    }
}

extension Transport {
    /// Consume frames as they come from the server and call `handleInboundFrame` on each of them.
    ///
    /// - Throws: Any error that occurs during task execution.
    func execute(_ serverFramesContinuation: AsyncStream<Frame>.Continuation) async throws {
        try await withThrowingTaskGroup { group in
            try await asyncNIOChannel.executeThenClose { inbound, outbound in
                group.addTask {
                    for try await frame in inbound {
                        serverFramesContinuation.yield(frame)
                    }
                }
                try await outbound.write(contentsOf: clientFrames)
            }
        }
    }

    func send(frame: Frame) {
        continuation?.yield(frame)
    }

    func send(frames: [Frame]) {
        frames.forEach { continuation?.yield($0) }
    }
}
