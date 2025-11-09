import NIOConcurrencyHelpers
import NIOCore

extension NIOLockedValueBox where Value == NIODeadline {
    fileprivate func setToNow() {
        self.withLockedValue {
            $0 = NIODeadline.now()
        }
    }
}

// - sends the heartbeats at specified intervals
// - if traffic happened then no heartbeat is required
// - if there is no traffic or heartbeats for 2 heartbeat intervals or longer,
// connection should be closed without any handshake
final class AMQPHeartbeatHandler: ChannelDuplexHandler, Sendable {
    typealias InboundIn = Frame
    typealias OutboundIn = Frame
    typealias InboundOut = Frame
    typealias OutboundOut = Frame

    let maxInterval: TimeAmount
    let heartbeatInterval: TimeAmount
    // scheduled repeated task handle
    private let heartbeatTask: NIOLockedValueBox<RepeatedTask?> = .init(nil)

    // last activity timestamps
    private let lastInboundActivity: NIOLockedValueBox<NIODeadline> = .init(.now())
    private let lastOutboundActivity: NIOLockedValueBox<NIODeadline> = .init(.now())
    var elapsedInbound: TimeAmount {
        self.lastInboundActivity.withLockedValue { return NIODeadline.now() - $0 }
    }
    var elapsedOutbound: TimeAmount {
        self.lastOutboundActivity.withLockedValue { return NIODeadline.now() - $0 }
    }

    // timeout in seconds
    init(timeout: UInt16) {
        precondition(timeout != 0)
        self.maxInterval = TimeAmount.seconds(Int64(timeout))
        self.heartbeatInterval = TimeAmount.seconds(Int64(max(timeout / 2, 1)))  // handling case of 1s
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.lastInboundActivity.setToNow()
        self.lastOutboundActivity.setToNow()
        let channel = context.channel
        self.heartbeatTask.withLockedValue {
            $0 = context.eventLoop.scheduleRepeatedTask(
                initialDelay: .zero,
                delay: self.heartbeatInterval
            ) { [weak self] task in
                guard let handler = self else { return }
                if handler.elapsedInbound > handler.maxInterval {
                    // drop the connection due to inactivity of the server
                    _ = channel.close().map { task.cancel() }
                }
                if handler.elapsedOutbound >= handler.heartbeatInterval {
                    _ = channel.writeAndFlush(HeartbeatFrame())
                        .map {
                            handler.lastOutboundActivity.setToNow()
                        }
                }
            }
        }
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.heartbeatTask.withLockedValue {
            $0?.cancel()
            $0 = nil
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        self.heartbeatTask.withLockedValue {
            $0?.cancel()
            $0 = nil
        }
        context.fireChannelInactive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        self.lastInboundActivity.setToNow()
        if unwrapInboundIn(data) as? HeartbeatFrame != nil {
            // consume the frame
            return
        }
        // propagate any other frames
        context.fireChannelRead(data)
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        self.lastOutboundActivity.setToNow()
        context.write(data, promise: promise)
    }
}
