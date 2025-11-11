import NIOCore

/// Handler to be used in NIO to negotiate properties and constraints between the server and the client,
/// it will be installed and perform the sequence dictated by a delegate (AMQPNegotiationDelegateProtocol),
/// and on success will remove itself from the pipeline
final class AMQPNegotiationHandler: ChannelInboundHandler,
    RemovableChannelHandler
{
    typealias InboundIn = Frame
    typealias OutboundOut = Frame

    static let handlerName = "AMQPNegotiationHandler"

    private let negotiator: any AMQPNegotiationDelegateProtocol
    // fulfilled when the negotiation is successful
    private let complete: EventLoopPromise<(Configuration, Spec.Table)>

    private func handle(action: TransportAction, on context: ChannelHandlerContext) throws {
        switch action {
        case .complete(let config, let serverProperties):
            context.pipeline.removeHandler(name: Self.handlerName, promise: nil)
            complete.succeed((config, serverProperties))
        case .error(let error):
            throw error
        case .reply(let frame):
            context.writeAndFlush(wrapOutboundOut(frame), promise: nil)
        case .several(let actions):
            for action in actions {
                try self.handle(action: action, on: context)
            }
        case .installHeartbeat(let timeout):
            let handler = AMQPHeartbeatHandler(timeout: timeout)
            try context.pipeline.syncOperations.addHandler(handler, position: .before(self))
        }
    }

    // MARK: - ChannelInboundHandler

    func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
        do {
            try handle(action: negotiator.start(), on: context)
        } catch {
            complete.fail(error)
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard let frame = unwrapInboundIn(data) as? MethodFrame else {
            context.fireErrorCaught(NegotiationError.unexpectedMethod)
            return
        }
        let action = negotiator.negotiate(frame: frame)
        do {
            try handle(action: action, on: context)
        } catch {
            complete.fail(error)
        }
    }

    // MARK: - init

    init(
        negotiator: any AMQPNegotiationDelegateProtocol,
        done: EventLoopPromise<(Configuration, Spec.Table)>
    ) {
        self.negotiator = negotiator
        self.complete = done
    }
}
