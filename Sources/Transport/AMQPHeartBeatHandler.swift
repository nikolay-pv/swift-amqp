import NIOConcurrencyHelpers
import NIOCore

extension NIOLockedValueBox where Value == NIODeadline {
    func resetValue() {
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
        self.lastInboundActivity.resetValue()
        self.lastOutboundActivity.resetValue()
        self.heartbeatTask.withLockedValue {
            $0 = context.eventLoop.scheduleRepeatedTask(
                initialDelay: .zero,
                delay: self.heartbeatInterval
            ) { task in
                if self.elapsedInbound > self.maxInterval {
                    // drop the connection due to inactivity of the server
                    _ = context.close()
                    task.cancel()
                    return
                }
                if self.elapsedOutbound >= self.heartbeatInterval {
                    // construct heartbeat frame according to your Frame API and send
                    let heartbeat = self.wrapOutboundOut(HeartbeatFrame())
                    _ = context.writeAndFlush(heartbeat, promise: nil)
                    self.lastOutboundActivity.resetValue()
                }
            }
        }

        context.fireChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        self.heartbeatTask.withLockedValue {
            $0?.cancel()
            $0 = nil
        }
        context.fireChannelInactive()
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.heartbeatTask.withLockedValue {
            $0?.cancel()
            $0 = nil
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        self.lastInboundActivity.resetValue()
        context.fireChannelRead(data)
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        self.lastOutboundActivity.resetValue()
        context.write(data, promise: promise)
    }
}
