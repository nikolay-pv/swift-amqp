import NIOCore

/// Handler to be used in NIO to negotiate properties and constraints between the server and the client,
/// it will be installed and perform the sequence dictated by a delegate (AMQPNegotiatorProtocol),
/// and on success will remove itself from the pipeline
class AMQPNegotitionHandler<T: AMQPNegotiatorProtocol>: ChannelInboundHandler,
    RemovableChannelHandler
{
    typealias InboundIn = Frame
    typealias OutboundOut = Frame

    let negotiator: T

    private func handle(action: TransportAction, on context: ChannelHandlerContext) {
        switch action {
        case .complete:
            context.pipeline.removeHandler(self, promise: nil)
        case .error(let error):
            context.fireErrorCaught(error)
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
        let frame = unwrapInboundIn(data) as? T.InputFrame
        guard let frame else {
            context.fireErrorCaught(ConnectionError.unexpectedMethod)
            return
        }
        handle(action: negotiator.negotiate(frame: frame), on: context)
    }

    init(negotiator: T) {
        self.negotiator = negotiator
    }
}
