import Logging
import NIOCore

protocol TransportProtocol: Sendable, AnyObject {
    init(
        host: String,
        port: Int,
        logger: Logger,
        inboundContinuation: AsyncStream<any Frame>.Continuation,
        negotiatorFactory: @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol & Sendable
    ) async throws

    var negotiatedProperties: (Configuration, Spec.Table) { get }
    var isActive: Bool { get }
    func execute() async

    func send(_ frame: any Frame) -> EventLoopPromise<any Frame>
    func send(_ frames: [any Frame]) -> EventLoopPromise<any Frame>
    func sendAsync(_ frame: any Frame)
    func sendAsync(_ frames: [any Frame])
}
