import NIOCore
import NIOPosix

/// Channel can be created off the Connection instance, by calling makeChannel method
///
/// @note Channel can't outlive the Connection which made it
public actor Channel {
    public let id: UInt16
    private unowned var connection: Connection
    private var promises: [EventLoopPromise<Frame>] = .init()
    private let eventLoop: EventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()

    /// method to handle incoming frames from a Broker
    internal func dispatch(frame: Frame) {
        // ideally will handle other frames too, but for now only ones it expects
        guard !promises.isEmpty else {
            return
        }
        precondition(!promises.isEmpty, "channel got an unexpected frame")
        let promise = promises.removeFirst()
        promise.succeed(frame)
    }

    // MARK: - init
    internal init(connection: Connection, id: UInt16) {
        self.id = id
        self.connection = connection
    }
}

// MARK: - Spec methods
extension Channel {

    fileprivate func sendReturningResponse(
        method: some AMQPMethodProtocol & FrameCodable,
    ) async throws -> MethodFrame? {
        let frame = MethodFrame(channelId: id, payload: method)
        let promise = eventLoop.makePromise(of: Frame.self)
        promises.append(promise)
        await connection.send(frame: frame)
        let response = try await promise.futureResult.get() as? MethodFrame
        return response
    }

    /// Requests a specific quality of service (QoS) for this `Channel` or for all channels on the `Connection`.
    /// The client can request that messages be sent in advance so that when the client finishes processing a
    /// message, the following message is already held locally, rather than needing to be sent down the channel.
    /// Prefetching gives a performance improvement.
    ///
    /// - Parameter prefetchSize: the prefetch window size in octets. The
    /// server will send a message in advance if it is equal to or smaller in size than the available prefetch size
    /// (and also falls into other prefetch limits). May be set to zero, meaning "no specific limit", although other
    /// prefetch limits may still apply. Can't be set to a value higher than Int32.max.
    /// The prefetch­size is ignored if the no­ack option is set.
    /// - Parameter prefetchCount: Specifies a prefetch window in terms of whole messages.
    /// This field may be used in combination with the prefetch­size field; a message will only be sent in
    /// advance if both prefetch windows (and those at the channel and connection level) allow it.
    /// Value must be larger or equal to 0 and smaller or equal than Int16.max.
    /// The prefetch­count is ignored if the no­ack option is set.
    /// - Parameter global: if set to `true` the QoS settings are applied to entire `Connection`.
    /// By default is `false`, i.e. settings are applied to the current instance of the `Channel` only.
    /// - Throws:
    public func basicQos(prefetchSize: Int = 0, prefetchCount: Int = 0, global: Bool = false)
        async throws
    {
        precondition(
            prefetchSize >= 0 && prefetchSize <= Int32.max,
            "prefetchSize should be within [0, Int32.max]"
        )
        precondition(
            prefetchCount >= 0 && prefetchCount <= Int16.max,
            "prefetchCount should be within [0, Int16.max]"
        )
        let method = Spec.Basic.Qos(
            prefetchSize: Int32(prefetchSize),
            prefetchCount: Int16(prefetchCount),
            global: global
        )
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Basic.QosOk,
            "basicQos expects Spec.Basic.QosOk but got \(String(describing: frame))"
        )
    }

    public func exchangeDeclare(named exchangeName: String) async throws {
        let method = Spec.Exchange.Declare(exchange: exchangeName, durable: true)
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Exchange.DeclareOk,
            "exchangeDeclare expects Spec.Exchange.DeclareOk but got \(String(describing: frame))"
        )
    }

    public func queueDeclare(named queueName: String) async throws -> Spec.Queue.DeclareOk {
        let method = Spec.Queue.Declare(queue: queueName, durable: true)
        let frame = try await sendReturningResponse(method: method)
        guard let payload = frame?.payload as? Spec.Queue.DeclareOk else {
            preconditionFailure(
                "queueDeclare expects Spec.Exchange.DeclareOk but got \(String(describing: frame))"
            )
        }
        return payload
    }

    public func queueBind(queue: String, exchange: String, routingKey: String? = nil) async throws {
        let method = Spec.Queue.Bind(
            ticket: 0,
            queue: queue,
            exchange: exchange,
            routingKey: routingKey ?? "",
            nowait: false,
            arguments: .init()
        )
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Queue.BindOk,
            "queueBind expects Spec.Queue.BindOk but got \(String(describing: frame)))"
        )
    }

    public func basicPublish(exchange: String, routingKey: String, body: String) async throws {
        let method = Spec.Basic.Publish(exchange: exchange, routingKey: routingKey)
        let frame = MethodFrame(channelId: self.id, payload: method)
        let contentProps = Spec.BasicProperties()
        let contentHeaderFrame = ContentHeaderFrame(
            channelId: self.id,
            classId: method.amqpClassId,
            bodySize: UInt64(body.utf8.count),
            properties: contentProps
        )
        let contentFrame = ContentBodyFrame(channelId: self.id, fragment: [UInt8].init(body.utf8))
        await connection.send(frames: [frame, contentHeaderFrame, contentFrame])
    }

    // start receiving the messages too
    internal func requestOpen() async throws {
        let method = Spec.Channel.Open()
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Channel.OpenOk,
            "Channel.requestOpen expects Spec.Channel.OpenOk but got \(String(describing: frame))"
        )
    }
}
