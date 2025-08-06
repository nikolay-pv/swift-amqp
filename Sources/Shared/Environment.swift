class Environment {
    typealias NegotiationFactoryT =
        (Configuration, Spec.Table) -> any AMQPNegotiationDelegateProtocol
    private(set) var negotiationFactory: NegotiationFactoryT = Spec.AMQPNegotiator.init

    func setNegotiationFactory(factory: @escaping NegotiationFactoryT) {
        self.negotiationFactory = factory
    }

    typealias TransportFactoryT = @Sendable (
        String, Int, AsyncStream<any Frame>.Continuation, AsyncStream<any Frame>,
        @escaping @Sendable () -> any AMQPNegotiationDelegateProtocol
    ) async throws -> any TransportProtocol & ~Copyable & Sendable
    private(set) var transportFactory: TransportFactoryT = Transport.init

    func setTransportFactory(factory: @escaping TransportFactoryT) {
        self.transportFactory = factory
    }

    nonisolated(unsafe) static var shared: Environment = Environment()
}
