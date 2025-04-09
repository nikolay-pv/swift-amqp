enum TransportAction {
    case reply(AMQPNegotitionHandler.OutboundOut)
    case replySeveral([AMQPNegotitionHandler.OutboundOut])
    case error(Error)
    case complete
}

/// A delegate for AMQPNegotiationHandler
protocol AMQPNegotiatorProtocol {
    associatedtype InputFrame
    func start() -> TransportAction
    func negotiate(frame: InputFrame) -> TransportAction
}
