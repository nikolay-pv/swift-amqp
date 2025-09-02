import Logging

struct Environment: Sendable {
    typealias NegotiationFactoryT = @Sendable
    (Configuration, Spec.Table) -> any AMQPNegotiationDelegateProtocol
    private(set) var negotiationFactory: NegotiationFactoryT = Spec.AMQPNegotiator.init

    mutating func setNegotiationFactory(factory: @escaping NegotiationFactoryT) {
        self.negotiationFactory = factory
    }

    typealias TransportFactoryT = @Sendable (
        String, Int, Logger, AsyncStream<any Frame>.Continuation, AsyncStream<any Frame>,
        @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol
    ) async throws -> any TransportProtocol & ~Copyable & Sendable
    private(set) var transportFactory: TransportFactoryT = Transport.init

    mutating func setTransportFactory(factory: @escaping TransportFactoryT) {
        self.transportFactory = factory
    }

    static let shared: Environment = .init()
}
