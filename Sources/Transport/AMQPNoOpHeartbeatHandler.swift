import NIOConcurrencyHelpers
import NIOCore

// @brief No-op heartbeat handler, used when the client and server negotiated
// timeout of 0, but in case there are still heartbeat frames received, they
// should be consumed and not propagated to the rest of the pipeline to avoid
// failures
final class AMQPNoOpHeartbeatHandler: ChannelDuplexHandler, Sendable {
    typealias InboundIn = TransportEvent
    typealias OutboundIn = Frame
    typealias InboundOut = TransportEvent
    typealias OutboundOut = Frame

    init() {}

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        if case .frame(let frame) = unwrapInboundIn(data),
            frame is HeartbeatFrame
        {
            // consume the frame
            return
        }
        // propagate any other frames
        context.fireChannelRead(data)
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.write(data, promise: promise)
    }
}
