import Logging
import NIOCore

protocol TransportProtocol: Sendable {
    init(
        host: String,
        port: Int,
        logger: Logger,
        inboundContinuation: AsyncStream<any Frame>.Continuation,
        negotiatorFactory: @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol
    ) async throws

    var isActive: Bool { get }
    func execute() async

    func send(_ frame: any Frame) -> EventLoopPromise<any Frame>
    func send(_ frames: [any Frame]) -> EventLoopPromise<any Frame>
}
