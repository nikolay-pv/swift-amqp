import AsyncAlgorithms
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix

#if DebugNIOEventHandlers
    import NIOExtras
#endif

final class Transport: TransportProtocol, Sendable {
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private let asyncNIOChannel: NIOAsyncChannel<any Frame, any Frame>

    private let outboundContinuation: AsyncStream<any Frame>.Continuation
    private let outboundFrames: AsyncStream<any Frame>
    private let inboundContinuation: AsyncStream<any Frame>.Continuation
    let negotiatedProperties: (Configuration, Spec.Table)

    init(
        host: String = "localhost",
        port: Int = 5672,
        logger: Logger,
        inboundContinuation: AsyncStream<any Frame>.Continuation,
        negotiatorFactory: @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol
    ) async throws {
        // one event loop per connection
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        // create outbound AsyncStream
        var outboundContinuation: AsyncStream<any Frame>.Continuation?
        self.outboundFrames = AsyncStream { continuation in
            outboundContinuation = continuation
        }
        guard let outboundContinuation else {
            fatalError("Couldn't create outbound AsyncStream")
        }
        // save continuation for later use
        self.outboundContinuation = outboundContinuation

        self.inboundContinuation = inboundContinuation
        let negotiationComplete = eventLoopGroup.any()
            .makePromise(of: (Configuration, Spec.Table).self)
        self.asyncNIOChannel = try await ClientBootstrap(group: eventLoopGroup)
            .connect(host: host, port: port) { channel in
                return channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(
                        ByteToMessageHandler(ByteToFrameCoderHandler())
                    )
                    try channel.pipeline.syncOperations.addHandler(
                        MessageToByteHandler(ByteToFrameCoderHandler())
                    )
                    #if DebugNIOEventHandlers
                        try channel.pipeline.syncOperations.addHandler(
                            DebugOutboundEventsHandler { event, _ in
                                logger.debug("\(event)")
                            }
                        )
                        try channel.pipeline.syncOperations.addHandler(
                            DebugInboundEventsHandler { event, _ in logger.debug("\(event)")
                            }
                        )
                    #endif  // DebugNIOEventHandlers
                    try channel.pipeline.syncOperations.addHandler(
                        AMQPNegotiationHandler(
                            negotiator: negotiatorFactory(),
                            done: negotiationComplete
                        ),
                        name: AMQPNegotiationHandler.handlerName
                    )
                    return try NIOAsyncChannel<any Frame, any Frame>(
                        wrappingChannelSynchronously: channel
                    )
                }
            }
        var negotiationResult = try await negotiationComplete.futureResult.get()
        // for security reasons reset credentials after negotiation
        negotiationResult.0.credentials.reset()
        negotiatedProperties = negotiationResult
    }

    deinit {
        try? asyncNIOChannel.channel.close().wait()
    }
}

extension Transport {
    var isActive: Bool {
        self.asyncNIOChannel.channel.isActive
    }

    // sends a frame to the broker through the established connection,
    // the caller is responsible for making sure that the `Transport.isActive`
    func send(_ frame: any Frame) -> EventLoopPromise<any Frame> {
        let promise = eventLoopGroup.any().makePromise(of: (any Frame).self)
        outboundContinuation.yield(frame)
        return promise
    }

    // same as send(_ frame: Frame) but for multiple frames
    func send(_ frames: [any Frame]) -> EventLoopPromise<any Frame> {
        let promise = eventLoopGroup.any().makePromise(of: (any Frame).self)
        frames.forEach {
            outboundContinuation.yield($0)
        }
        return promise
    }

    func sendAsync(_ frame: any Frame) {
        outboundContinuation.yield(frame)
    }

    func sendAsync(_ frames: [any Frame]) {
        frames.forEach {
            outboundContinuation.yield($0)
        }
    }

    /// Receives and sends out frames as they come through the AsyncStream's passed on construction of the object
    ///
    /// - Throws: Any error that occurs during task execution.
    func execute() async {
        do {
            try await withThrowingTaskGroup { group in
                try await asyncNIOChannel
                    .executeThenClose { inbound, outbound in
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
            fatalError("Unexpected error in TransportProtocol::execute(): \(error)")
        }
    }
}
