import NIOCore

/// Handler to be used in NIO to negotiate properties and constraints between the server and the client,
/// it will be installed and perform the sequence dictated by a delegate (AMQPNegotiationDelegateProtocol),
/// and on success will remove itself from the pipeline
final class AMQPNegotiationHandler: ChannelInboundHandler,
    RemovableChannelHandler
{
    typealias InboundIn = Frame
    typealias OutboundOut = Frame

    // used to remove the handler from the pipeline when negotiation completes
    static let handlerName = "AMQPNegotiationHandler"

    private let negotiator: any AMQPNegotiationDelegateProtocol
    // fulfilled when the negotiation is successful
    private let complete: EventLoopPromise<(Configuration, Spec.Table)>

    // absolute timeout to wait for frames from the server during negotiation
    static let negotiationTimeout = TimeAmount.seconds(30)
    private var negotiationInterrupt: RepeatedTask?
    private func setupGlobalTimeout(on context: ChannelHandlerContext) {
        negotiationInterrupt?.cancel()
        let channel = context.channel
        let promise = complete
        negotiationInterrupt = context.eventLoop.scheduleRepeatedTask(
            initialDelay: Self.negotiationTimeout,
            delay: Self.negotiationTimeout
        ) { task in
            // drop the connection due to inactivity
            _ = channel.close()
                .map {
                    promise.fail(NegotiationError.timedOut)
                }
        }
    }

    private func handle(action: TransportAction, on context: ChannelHandlerContext) throws {
        setupGlobalTimeout(on: context)
        switch action {
        case .complete(let config, let serverProperties):
            negotiationInterrupt?.cancel()
            context.pipeline.removeHandler(name: Self.handlerName, promise: nil)
            complete.succeed((config, serverProperties))
        case .error(let error):
            negotiationInterrupt?.cancel()
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
