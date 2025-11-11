import Logging

struct Environment: Sendable {
    typealias NegotiationFactoryT =
        @Sendable (Configuration, Spec.Table) -> any AMQPNegotiationDelegateProtocol

    typealias TransportFactoryT =
        @Sendable (
            String, Int, Logger, AsyncStream<any Frame>.Continuation,
            @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol
        ) async throws -> any TransportProtocol & Sendable

    private(set) var negotiationFactory: NegotiationFactoryT = Spec.AMQPNegotiator.init
    private(set) var transportFactory: TransportFactoryT = Transport.init
    static let shared: Environment = .init()
}
