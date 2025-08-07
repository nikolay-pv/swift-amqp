protocol TransportProtocol: ~Copyable, Sendable {
    init(
        host: String,
        port: Int,
        inboundContinuation: AsyncStream<Frame>.Continuation,
        outboundFrames: AsyncStream<Frame>,
        negotiatorFactory: @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol
    ) async throws

    func execute() async throws
}
