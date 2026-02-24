import Logging
import NIOCore

protocol TransportProtocol: Sendable, AnyObject {
    init(
        host: String,
        port: Int,
        logger: Logger,
        inboundContinuation: AsyncStream<any Frame>.Continuation,
        negotiatorFactory: @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol
    ) async throws

    var negotiatedProperties: (Configuration, Spec.Table) { get }
    var isActive: Bool { get }

    /// stops the Frame routing and processing and drops the connection (without close Handshake)
    func stop()
    /// drops the connection
    func drop()

    func send(_ frame: any Frame) -> EventLoopPromise<any Frame>
    func send(_ frames: [any Frame]) -> EventLoopPromise<any Frame>
    func sendAsync(_ frame: any Frame)
    func sendAsync(_ frames: [any Frame])
}
