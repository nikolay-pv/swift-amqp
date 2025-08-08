import NIOCore

/// Handler to be used in NIO to negotiate properties and constraints between the server and the client,
/// it will be installed and perform the sequence dictated by a delegate (AMQPNegotiationDelegateProtocol),
/// and on success will remove itself from the pipeline
class AMQPNegotiationHandler: ChannelInboundHandler,
    RemovableChannelHandler
{
    typealias InboundIn = Frame
    typealias OutboundOut = Frame

    static let handlerName = "AMQPNegotiationHandler"

    let negotiator: any AMQPNegotiationDelegateProtocol
    // fulfilled when the negotiation is successful
    let complete: EventLoopPromise<Void>

    private func handle(action: TransportAction, on context: ChannelHandlerContext) {
        switch action {
        case .complete:
            context.pipeline.removeHandler(name: Self.handlerName, promise: nil)
            complete.succeed()
        case .error(let error):
            complete.fail(error)
        case .reply(let frame):
            context.writeAndFlush(wrapOutboundOut(frame), promise: nil)
        case .replySeveral(let frames):
            for frame in frames {
                context.writeAndFlush(wrapOutboundOut(frame), promise: nil)
            }
        }
    }

    func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
        handle(action: negotiator.start(), on: context)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard let frame = unwrapInboundIn(data) as? MethodFrame else {
            context.fireErrorCaught(NegotiationError.unexpectedMethod)
            return
        }
        let action = negotiator.negotiate(frame: frame)
        handle(action: action, on: context)
    }

    init(negotiator: any AMQPNegotiationDelegateProtocol, done: EventLoopPromise<Void>) {
        self.negotiator = negotiator
        self.complete = done
    }
}
