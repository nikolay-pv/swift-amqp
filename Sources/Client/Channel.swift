import Logging
import NIOCore

/// Channel can be created off the Connection instance, by calling makeChannel method
///
/// @note Channel can't outlive the Connection which made it
public actor Channel {
    public let id: UInt16
    private(set) var isOpen = true
    private weak var transportWeak: (any TransportProtocol)?
    private let logger: Logger
    private var promises: [EventLoopPromise<any Frame>] = .init()
    private let messages: AsyncStream<Message>
    private let continuation: AsyncStream<Message>.Continuation?
    private var content: Message?
    private var expectedContentSize: UInt64?
    private var deliverMethod: Spec.Basic.Deliver?

    /// method to handle incoming frames from a Broker
    internal func dispatch(frame: any Frame) {
        if let methodFrame = frame as? MethodFrame,
            let method = methodFrame.payload as? Spec.Basic.Deliver
        {
            self.deliverMethod = method
            return
        }
        if isContent(frame) {
            if let header = frame as? ContentHeaderFrame {
                guard let deliverMethod = self.deliverMethod else {
                    preconditionFailure("Received content frame without prior deliver method")
                }
                self.expectedContentSize = header.bodySize
                self.content = .init(
                    body: [],
                    properties: header.properties,
                    channel: self,
                    deliveryTag: deliverMethod.deliveryTag
                )
            } else if let body = frame as? ContentBodyFrame {
                self.content?.body.append(contentsOf: body.fragment)
            }
            if self.expectedContentSize == UInt64(self.content?.body.count ?? .max) {
                continuation?.yield(self.content!)
                self.content = nil
                self.deliverMethod = nil
            }
            return
        }
        // ideally will handle other frames too, but for now only ones it expects
        guard !promises.isEmpty else {
            return
        }
        precondition(!promises.isEmpty, "channel got an unexpected frame")
        let promise = promises.removeFirst()
        promise.succeed(frame)
    }

    // MARK: - init
    internal init(transport: any TransportProtocol, id: UInt16, logger: Logger) {
        self.id = id
        self.transportWeak = transport
        var decoratedLogger = logger
        decoratedLogger[metadataKey: "channel-id"] = "\(id)"
        self.logger = decoratedLogger
        var messagesContinuation: AsyncStream<Message>.Continuation?
        self.messages = AsyncStream { continuation in
            messagesContinuation = continuation
        }
        self.continuation = messagesContinuation
    }
}

// MARK: - Spec methods
extension Channel {
    /// Returns the owned transport for use in closures, or throws if the channel or connection is closed.
    ///
    /// - Throws: `ConnectionError.channelIsClosed` if the channel is closed, or
    ///   `ConnectionError.connectionIsClosed` if the transport is closed.
    /// - Parameter closure: A closure that takes the transport and returns a value of type `T`.
    /// - Returns: The result of the closure executed with the transport.
    private func withTransport<T>(_ closure: (any TransportProtocol) -> T) throws -> T {
        guard isOpen else {
            throw ConnectionError.channelIsClosed
        }
        guard let transport = self.transportWeak, transport.isActive else {
            throw ConnectionError.connectionIsClosed
        }
        return closure(transport)
    }

    nonisolated internal func makeFrame(
        with method: any AMQPMethodProtocol & FrameCodable
    ) -> MethodFrame {
        return MethodFrame(channelId: id, payload: method)
    }

    internal func handleConnectionError(_ error: Error) {
        for promise in promises {
            promise.fail(error)
        }
    }

    private func sendReturningResponse(
        method: some AMQPMethodProtocol & FrameCodable,
    ) async throws -> MethodFrame? {
        let frame = makeFrame(with: method)
        let promise = try withTransport {
            $0.send(frame)
        }
        promises.append(promise)
        let response = try await promise.futureResult.get() as? MethodFrame
        return response
    }

    public func close(replyCode: Int16 = 0, replyText: String = "") async throws {
        let method = Spec.Channel.Close(
            replyCode: replyCode,
            replyText: replyText,
            classId: 0,
            methodId: 0
        )
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Channel.CloseOk,
            "close expects Spec.Channel.CloseOk but got \(String(describing: frame))"
        )
        self.isOpen = false
    }

    // this is only used on channel0
    internal func connectionClose(
        replyCode: Int16 = 0,
        replyText: String = "",
        classId: Int16 = 0,
        methodId: Int16 = 0
    ) async throws {
        let method = Spec.Connection.Close(
            replyCode: replyCode,
            replyText: replyText,
            classId: classId,
            methodId: methodId
        )
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Connection.CloseOk,
            "close expects Spec.Connection.CloseOk but got \(String(describing: frame))"
        )
    }

    // this is only used on channel0
    internal func connectionCloseOk() {
        let method = Spec.Connection.CloseOk()
        let frame = makeFrame(with: method)
        // if transport was already destroyed nothing can be done then
        _ = transportWeak?.send(frame)
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

    /// Declares a queue and returns information about it.
    /// - Parameter queueName: the name of the queue to declare.
    /// - Returns: info about the queue on success, see `QueueDeclareResult`.
    public func queueDeclare(named queueName: String) async throws -> QueueDeclareResult {
        let method = Spec.Queue.Declare(queue: queueName, durable: true)
        let frame = try await sendReturningResponse(method: method)
        guard let payload = frame?.payload as? Spec.Queue.DeclareOk else {
            preconditionFailure(
                "queueDeclare expects Spec.Queue.DeclareOk but got \(String(describing: frame))"
            )
        }
        return QueueDeclareResult(
            queueName: payload.queue,
            messageCount: Int(payload.messageCount),
            consumerCount: Int(payload.consumerCount)
        )
    }

    // asks broker to bind the queue to exchange waiting for a confirmation
    /// - Parameters:
    ///   - queue: the name of the queue.
    ///   - exchange: the name of the exchange.
    ///   - routingKey: the routing key to use. If not provided, the queue name will be used as the routing key.
    ///   - nowait: doesn't wait for a response from the broker, but let broker to raise exception if it didn't work.
    ///  - Throws: if sending fails or the broker responds with an error.
    public func queueBind(
        queue: String,
        exchange: String,
        routingKey: String? = nil,
        nowait: Bool = false,
        arguments: Spec.Table = .init()
    ) async throws {
        let method = Spec.Queue.Bind(
            ticket: 0,
            queue: queue,
            exchange: exchange,
            routingKey: routingKey ?? queue,
            nowait: nowait,
            arguments: arguments
        )
        if nowait {
            let frame = makeFrame(with: method)
            _ = try withTransport {
                $0.send(frame)
            }
            return
        }
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Queue.BindOk,
            "queueBind expects Spec.Queue.BindOk but got \(String(describing: frame)))"
        )
    }

    public func basicPublish(exchange: String, routingKey: String, body: String) async throws {
        let method = Spec.Basic.Publish(exchange: exchange, routingKey: routingKey)
        let frame = makeFrame(with: method)
        let contentProps = Spec.BasicProperties()
        let contentHeaderFrame = ContentHeaderFrame(
            channelId: self.id,
            classId: method.amqpClassId,
            bodySize: UInt64(body.utf8.count),
            properties: contentProps
        )
        let contentFrame = ContentBodyFrame(channelId: self.id, fragment: [UInt8].init(body.utf8))
        _ = try withTransport {
            $0.send([frame, contentHeaderFrame, contentFrame])
        }
    }

    public func basicConsume(queue: String, tag: String) async throws -> AsyncStream<Message> {
        let method = Spec.Basic.Consume(queue: queue, consumerTag: tag)
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Basic.ConsumeOk,
            "basicConsume expects Spec.Basic.ConsumeOk but got \(String(describing: frame))"
        )
        return messages
    }

    /// Sends ack for one or more messages on this channel.
    /// - Parameters:
    ///   - deliveryTag: the delivery tag of the message to acknowledge.
    ///   - multiple: if true, acknowledges all messages up to and including this one.
    public func basicAck(deliveryTag: Int64, multiple: Bool = false) async throws {
        let method = Spec.Basic.Ack(deliveryTag: deliveryTag, multiple: multiple)
        let frame = makeFrame(with: method)
        _ = try withTransport {
            $0.send(frame)
        }
    }

    /// Sends nack for one or more messages on this channel.
    /// - Parameters:
    ///   - deliveryTag: the delivery tag of the message to reject.
    ///   - multiple: if true, rejects all messages up to and including this one.
    ///   - requeue: if true, the message will be requeued.
    public func basicNack(deliveryTag: Int64, multiple: Bool = false, requeue: Bool = true)
        async throws
    {
        let method = Spec.Basic.Nack(
            deliveryTag: deliveryTag,
            multiple: multiple,
            requeue: requeue
        )
        let frame = makeFrame(with: method)
        _ = try withTransport {
            $0.send(frame)
        }
    }

    // this will start receiving the messages from Transport too
    internal func requestOpen() async throws {
        let method = Spec.Channel.Open()
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Channel.OpenOk,
            "Channel.requestOpen expects Spec.Channel.OpenOk but got \(String(describing: frame))"
        )
    }
}
