enum TransportAction {
    case reply(any AMQPNegotiationHandler.OutboundOut)
    case replySeveral([any AMQPNegotiationHandler.OutboundOut])
    case error(Error)
    case complete
}

/// A delegate for AMQPNegotiationHandler
protocol AMQPNegotiationDelegateProtocol {
    func start() -> TransportAction
    func negotiate(frame: MethodFrame) -> TransportAction
}
