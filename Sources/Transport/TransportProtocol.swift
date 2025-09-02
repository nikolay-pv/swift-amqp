import Logging

protocol TransportProtocol: ~Copyable, Sendable {
    init(
        host: String,
        port: Int,
        logger: Logger,
        inboundContinuation: AsyncStream<any Frame>.Continuation,
        outboundFrames: AsyncStream<any Frame>,
        negotiatorFactory: @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol
    ) async throws

    func execute() async
}
