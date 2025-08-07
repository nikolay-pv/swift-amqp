enum TransportAction {
    case reply(AMQPNegotiationHandler.OutboundOut)
    case replySeveral([AMQPNegotiationHandler.OutboundOut])
    case error(Error)
    case complete
}

/// A delegate for AMQPNegotiationHandler
protocol AMQPNegotiationDelegateProtocol {
    func start() -> TransportAction
    func negotiate(frame: MethodFrame) -> TransportAction
}
