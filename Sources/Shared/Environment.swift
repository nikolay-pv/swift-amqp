import Logging

struct Environment: Sendable {
    typealias NegotiationFactoryT =
        @Sendable
    (Configuration, Spec.Table) -> any AMQPNegotiationDelegateProtocol & Sendable
    private(set) var negotiationFactory: NegotiationFactoryT = Spec.AMQPNegotiator.init

    mutating func setNegotiationFactory(factory: @escaping NegotiationFactoryT) {
        self.negotiationFactory = factory
    }

    typealias TransportFactoryT =
        @Sendable (
            String, Int, Logger, AsyncStream<any Frame>.Continuation,
            @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol & Sendable
        ) async throws -> any TransportProtocol & Sendable
    private(set) var transportFactory: TransportFactoryT = Transport.init

    mutating func setTransportFactory(factory: @escaping TransportFactoryT) {
        self.transportFactory = factory
    }

    static let shared: Environment = .init()
}
