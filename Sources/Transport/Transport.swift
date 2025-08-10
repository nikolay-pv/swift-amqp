import AsyncAlgorithms
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix

#if canImport(NIOExtras)
    import NIOExtras
#endif

struct Transport: ~Copyable, TransportProtocol, Sendable {
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private let asyncNIOChannel: NIOAsyncChannel<any Frame, any Frame>

    private let outboundFrames: AsyncStream<any Frame>
    private let inboundContinuation: AsyncStream<any Frame>.Continuation

    init(
        host: String = "localhost",
        port: Int = 5672,
        inboundContinuation: AsyncStream<any Frame>.Continuation,
        outboundFrames: AsyncStream<any Frame>,
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
                        return try NIOAsyncChannel<any Frame, any Frame>(
                            wrappingChannelSynchronously: channel
                        )
                    }
            }
        try await negotiationComplete.futureResult.get()
        self.eventLoopGroup = eventLoopGroup
        self.asyncNIOChannel = asyncNIOChannel
        self.outboundFrames = outboundFrames
        self.inboundContinuation = inboundContinuation
    }

    deinit {
        try? asyncNIOChannel.channel.close().wait()
    }
}

extension Transport {
    /// Receives and sends out frames as they come through the AsyncStream's passed on construction of the object
    ///
    /// - Throws: Any error that occurs during task execution.
    func execute() async {
        do {
            try await withThrowingTaskGroup { group in
                try await asyncNIOChannel.executeThenClose { inbound, outbound in
                    let continuation = self.inboundContinuation
                    group.addTask {
                        do {
                            for try await frame in inbound {
                                continuation.yield(frame)
                            }
                        } catch {
                            // the inbound channel has been closed due to an exception (likely stopped iterating),
                            // propagate this down to consumers
                            continuation.finish()
                        }
                    }
                    do {
                        try await outbound.write(contentsOf: outboundFrames)
                    } catch {
                        // the outbound channel has been closed due to an exception (likely stopped iterating)
                        // swallow the error as there is nobody to notify this about
                        // because this means that owning Channel has been stopped / closed
                    }
                }
            }
        } catch {
            // it should never happen, but if it does, log a warning, there is
            // no withThrowingTaskGroup which accepts non-throwing closure
            print("WARNING: unexpected Error \(error) in TransportProtocol::execute()")
        }
    }
}
