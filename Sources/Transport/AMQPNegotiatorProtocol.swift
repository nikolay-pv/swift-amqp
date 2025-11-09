import NIOCore

indirect enum TransportAction {
    case reply(any AMQPNegotiationHandler.OutboundOut)
    case error(Error)
    case complete(Configuration, Spec.Table)
    case installHandler(any ChannelHandler & Sendable)
    case several([TransportAction])
}

/// A delegate for AMQPNegotiationHandler
protocol AMQPNegotiationDelegateProtocol {
    func start() -> TransportAction
    func negotiate(frame: MethodFrame) -> TransportAction
}
