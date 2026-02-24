import Atomics
import Logging
import NIOConcurrencyHelpers
import NIOCore

private struct ContentContext: Sendable {
    private(set) var channelId: UInt16 = 0
    private(set) var expectedBodyBytes: UInt64 = 0
    private(set) var actualBodyBytes: UInt64 = 0
    private(set) var contentFrames = [any Frame]()

    // channel 0 can't wait for content frames
    func waitForContent() -> Bool { channelId != 0 }
    func isComplete() -> Bool { actualBodyBytes == expectedBodyBytes }

    mutating func push(deliver: any Frame) {
        channelId = deliver.channelId
        contentFrames.append(deliver)
    }

    mutating func push(header: ContentHeaderFrame) {
        expectedBodyBytes = header.bodySize
        contentFrames.append(header)
    }

    mutating func push(body: ContentBodyFrame) {
        contentFrames.append(body)
        actualBodyBytes += UInt64(body.fragment.count)
    }

    mutating func reset() {
        channelId = 0
        expectedBodyBytes = 0
        actualBodyBytes = 0
        contentFrames.removeAll()
    }
}

/// Channel can be created off the Connection instance, by calling makeChannel method
///
/// @note Channel can't outlive the Connection which made it
public final class Channel: Sendable {
    public let id: UInt16
    // state
    private let state: ManagedAtomic<ObjectState> = .init(.open)
    private let closingError: NIOLockedValueBox<Error?> = .init(nil)
    public var isOpen: Bool { state.load(ordering: .acquiring) == .open }

    private weak let manager: ChannelManager?
    private let maxFrameSize: Int32
    // maximum possible fragment size for content body frames on this channel
    // calculated from negotiated frame size
    private var maxFragmentSize: Int32 { return ContentBodyFrame.maxPossibleFragmentSize(for: self.maxFrameSize) }
    private unowned let connection: Connection
    private let logger: Logger
    typealias MessageStreamT = AsyncThrowingStream<Message, Error>
    private let messages: MessageStreamT
    private let continuation: MessageStreamT.Continuation?
    private let promises: NIOLockedValueBox<[EventLoopPromise<any Frame>]> = .init([])
    private let contentContext: NIOLockedValueBox<ContentContext> = .init(ContentContext())

    /// method to handle incoming frames from a Broker
    internal func dispatch(frame: any Frame) {
        precondition(frame.channelId == self.id, "dispatch called with frame for different channel id")
        if let payload = frame.unwrapPayload(as: Spec.Channel.Close.self) {
            self.state.store(.closing, ordering: .releasing)
            let method = Spec.Connection.CloseOk()
            let frame = MethodFrame(channelId: 0, payload: method)
            // if connection is closed already so be it, thus `try?`
            try? self.withConnectionUnchecked { $0.sendAsync(frame) }
            self.state.store(.closed, ordering: .releasing)
            if payload.replyCode != 0 && payload.replyCode != 200 {
                guard let code = Spec.SoftError(rawValue: payload.replyCode) else {
                    fatalError(
                        "Broker sent unknown error reply code in Channel.Close frame: \(payload.replyCode) with message \(payload.replyText)"
                    )
                }
                let error = SoftError.broker(
                    code: code,
                    replyText: payload.replyText,
                    classId: payload.amqpClassId,
                    methodId: payload.amqpMethodId
                )
                self.closingError.withLockedValue {
                    $0 = ChannelError.wrap(softError: error)
                }
            }
            return
        }
        if frame.isPayload(of: Spec.Basic.Deliver.self) {
            contentContext.withLockedValue { $0.push(deliver: frame) }
            return
        }
        if frame.isContent() {
            precondition(
                contentContext.withLockedValue { $0.waitForContent() },
                "Received content frame without prior deliver method"
            )
            if let header = frame as? ContentHeaderFrame {
                contentContext.withLockedValue { $0.push(header: header) }
                return
            }
            if let body = frame as? ContentBodyFrame {
                // only ContentBodyFrame is checked for maxFrameSize
                // because there is no way to split other frames into smaller pieces
                // see also: https://www.rabbitmq.com/amqp-0-9-1-errata#section_11
                // check for exceeding expected body size
                // as per "4.2.3 General Frame Format"
                // in case maxFrameSize is exceeded the connection must be
                // closed
                if self.maxFrameSize != 0 && body.bytesCount > UInt32(self.maxFrameSize) {
                    // A peer MUST NOT send frames larger than the agreed-upon size.
                    self.connection.initiateClose(
                        replyCode: Spec.HardError.frameError.rawValue,
                        replyText:
                            "Received ContentBody Frame of size \(body.bytesCount) while max size agreed is \(self.maxFrameSize)",
                        classId: 60,
                        methodId: 60
                    )
                    return
                }
                contentContext.withLockedValue { $0.push(body: body) }
            }
            if contentContext.withLockedValue({ $0.isComplete() }) {
                let contentFrames = contentContext.withLockedValue {
                    let frames = $0.contentFrames
                    $0.reset()
                    return frames
                }
                self.dispatch(content: contentFrames)
            }
            return
        }
        precondition(
            promises.withLockedValue { !$0.isEmpty },
            "channel got an unexpected frame \(frame)"
        )
        let promise = promises.withLockedValue { $0.removeFirst() }
        promise.succeed(frame)
    }

    internal func dispatch(content: [any Frame]) {
        precondition(
            content.count > 2,
            "Content should have at least 3 frames (deliver, header, body)"
        )
        let deliverFrame = content[0] as! MethodFrame
        let headerFrame = content[1] as! ContentHeaderFrame
        var message = Message(
            body: [],
            deliverFrame: deliverFrame.payload as! Spec.Basic.Deliver,
            properties: headerFrame.properties,
            onChannel: self
        )
        content[2...]
            .forEach {
                if let bodyFrame = $0 as? ContentBodyFrame {
                    message.body.append(contentsOf: bodyFrame.fragment)
                } else {
                    preconditionFailure("Expected ContentBodyFrame but got \(type(of: $0))")
                }
            }
        continuation?.yield(message)
    }

    // MARK: - init
    internal init(
        connection: Connection,
        id: UInt16,
        logger: Logger,
        maxFrameSize: Int32,
        manager: ChannelManager? = nil
    ) {
        self.id = id
        self.manager = manager
        self.maxFrameSize = maxFrameSize
        self.connection = connection
        var decoratedLogger = logger
        decoratedLogger[metadataKey: "channel-id"] = "\(id)"
        self.logger = decoratedLogger
        var messagesContinuation: MessageStreamT.Continuation?
        self.messages = MessageStreamT { continuation in
            messagesContinuation = continuation
        }
        self.continuation = messagesContinuation
    }

    deinit {
        self.manager?.removeChannel(id: id)
        precondition(
            self.state.load(ordering: .acquiring) == .closed,
            "close() wasn't called on this channel object, which is required by the protocol"
        )
    }

    private func ensureOpen() throws {
        guard self.isOpen else {
            guard let error = self.closingError.withLockedValue({ $0 }) else {
                throw ChannelError.channelIsClosed("")
            }
            throw error
        }
    }

    // MARK:- helpers

    /// Returns the owned connection for use in closures, or throws if the channel or connection is closed.
    ///
    /// - Throws: `ChannelError.channelIsClosed` or `ConnectionError.connectionIsClosed`
    /// - Parameter closure: A closure that takes the connection and returns a value of type `T`.
    /// - Returns: The result of the closure executed with the connection.
    private func withConnection<T>(_ closure: (Connection) -> T) throws -> T {
        try self.ensureOpen()
        return try withConnectionUnchecked(closure)
    }

    // unchecked channel openness
    private func withConnectionUnchecked<T>(_ closure: (Connection) -> T) throws -> T {
        // store var to make sure it is alive for the duration of the closure
        let connection = self.connection
        try connection.ensureOpen()
        return closure(connection)
    }

    private func makeFrame(
        with method: any AMQPMethodProtocol & FrameCodable
    ) -> MethodFrame {
        return MethodFrame(channelId: id, payload: method)
    }

    internal func handleConnectionError(_ error: ConnectionError?) {
        let promises = promises.withLockedValue {
            let current = $0
            $0.removeAll()
            return current
        }
        let error = error ?? ConnectionError.connectionIsClosed
        for promise in promises {
            promise.fail(error)
        }
        continuation?.finish(throwing: error)
        self.state.store(.closed, ordering: .releasing)
        self.closingError.withLockedValue { $0 = error }
    }

    private func sendReturningResponse(
        method: some AMQPMethodProtocol & FrameCodable,
    ) async throws -> MethodFrame? {
        let frame = makeFrame(with: method)
        let promise = try promises.withLockedValue {
            let promise = try withConnection {
                $0.send(frame)
            }
            $0.append(promise)
            return promise
        }
        let response = try await promise.futureResult.get() as? MethodFrame
        return response
    }
}

// MARK: - Spec methods
extension Channel {
    /// Requests a specific quality of service (QoS) for this `Channel` or for all channels on the `Connection`.
    /// The client can request that messages be sent in advance so that when the client finishes processing a
    /// message, the following message is already held locally, rather than needing to be sent down the channel.
    /// Prefetching gives a performance improvement.
    ///
    /// - Parameters:
    /// - prefetchSize: the prefetch window size in octets. The
    /// server will send a message in advance if it is equal to or smaller in size than the available prefetch size
    /// (and also falls into other prefetch limits). May be set to zero, meaning "no specific limit", although other
    /// prefetch limits may still apply. Can't be set to a value higher than Int32.max.
    /// The prefetch­size is ignored if the no­ack option is set.
    /// - prefetchCount: Specifies a prefetch window in terms of whole messages.
    /// This field may be used in combination with the prefetch­size field; a message will only be sent in
    /// advance if both prefetch windows (and those at the channel and connection level) allow it.
    /// Value must be larger or equal to 0 and smaller or equal than Int16.max.
    /// The prefetch­count is ignored if the no­ack option is set.
    /// - global: if set to `true` the QoS settings are applied to entire `Connection`.
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
            prefetchCount >= 0 && prefetchCount <= UInt16.max,
            "prefetchCount should be within [0, Int16.max]"
        )
        let method = Spec.Basic.Qos(
            prefetchSize: Int32(prefetchSize),
            prefetchCount: UInt16(prefetchCount),
            global: global
        )
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Basic.QosOk,
            "basicQos expects Spec.Basic.QosOk but got \(String(describing: frame))"
        )
    }

    /// Declares an exchange on the broker.
    /// If the exchange doesn't exist already, if it exists the broker will verify the parameters match
    /// and return an error if they don't.
    ///
    /// - Parameters:
    ///   - exchangeName: the name of the exchange to declare.
    ///   - type: the type of the exchange.
    ///   - durable: if true, the exchange will survive a broker restart.
    ///   - autoDelete: if true, the exchange will be deleted when no more queues are bound to it.
    ///   - internal: if true, can only be published to by other exchanges but not the clients.
    ///   - passive: if true, checks if the same named exchange exists with the same parameters.
    ///   - arguments: table with additional keys and values to be used when declaring the exchange.
    ///
    /// - Throws: if connection or this channel has been already closed.
    public func exchangeDeclare(
        named exchangeName: String,
        type: ExchangeType = ExchangeType.direct,
        durable: Bool = false,
        autoDelete: Bool = false,
        internal: Bool = false,
        passive: Bool = false,
        arguments: Spec.Table = [:]
    ) async throws {
        try validate(shortName: exchangeName)
        let method = Spec.Exchange.Declare(
            exchange: exchangeName,
            type: type.rawValue,
            passive: passive,
            durable: durable,
            autoDelete: autoDelete,
            internal: `internal`,
            nowait: false,
            arguments: arguments
        )
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Exchange.DeclareOk,
            "exchangeDeclare expects Spec.Exchange.DeclareOk but got \(String(describing: frame))"
        )
    }

    /// Declares an exchange on the broker without waiting for a confirmation from the broker.
    /// See ``exchangeDeclare(named:type:durable:autoDelete:internal:passive:arguments:)`` for parameter and exception details.
    public func exchangeDeclareNoWait(
        named exchangeName: String,
        type: ExchangeType = ExchangeType.direct,
        durable: Bool = false,
        autoDelete: Bool = false,
        internal: Bool = false,
        passive: Bool = false,
        arguments: Spec.Table = [:]
    ) async throws {
        try validate(shortName: exchangeName)
        let method = Spec.Exchange.Declare(
            exchange: exchangeName,
            type: type.rawValue,
            passive: passive,
            durable: durable,
            autoDelete: autoDelete,
            internal: `internal`,
            nowait: true,
            arguments: arguments
        )
        let frame = makeFrame(with: method)
        try withConnection {
            $0.sendAsync(frame)
        }
    }

    /// Declares a queue and returns information about it.
    /// - Parameters:
    ///  - queueName: the name of the queue to declare.
    ///  - durable: if true, the queue will survive a broker restart.
    ///  - exclusive: if true, the queue will be used by only one connection.
    ///  - autoDelete: if true, the queue will be deleted when the consumer disconnects.
    ///  - passive: if true, the server will reply with Declare-Ok if the queue already exists with the same
    ///    parameters, and raise an error if not.
    ///  - arguments: table with additional keys and values to be used when declaring the queue
    /// - Returns: info about the queue on success, see `QueueDeclareResult`.
    ///  - Throws: if connection or this channel has been already closed.
    public func queueDeclare(
        named queueName: String,
        durable: Bool = false,
        exclusive: Bool = false,
        autoDelete: Bool = false,
        passive: Bool = false,
        arguments: Spec.Table = [:]
    ) async throws -> QueueDeclareResult {
        try validate(shortName: queueName)
        let method = Spec.Queue.Declare(
            queue: queueName,
            passive: passive,
            durable: durable,
            exclusive: exclusive,
            autoDelete: autoDelete,
            arguments: arguments
        )
        let frame = try await sendReturningResponse(method: method)
        guard let payload = frame?.unwrapPayload(as: Spec.Queue.DeclareOk.self) else {
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

    /// Declares a queue without waiting for a confirmation from the broker.
    /// See ``queueDeclare(named:durable:exclusive:autoDelete:passive:arguments:)`` for parameter and exception details.
    public func queueDeclareNoWait(
        named queueName: String,
        durable: Bool = false,
        exclusive: Bool = false,
        autoDelete: Bool = false,
        passive: Bool = false,
        arguments: Spec.Table = [:]
    ) async throws {
        try validate(shortName: queueName)
        let method = Spec.Queue.Declare(
            queue: queueName,
            passive: passive,
            durable: durable,
            exclusive: exclusive,
            autoDelete: autoDelete,
            nowait: true,
            arguments: arguments
        )

        let frame = makeFrame(with: method)
        try withConnection {
            $0.sendAsync(frame)
        }
    }

    // asks broker to bind the queue to exchange waiting for a confirmation
    /// - Parameters:
    ///   - queue: the name of the queue.
    ///   - exchange: the name of the exchange.
    ///   - routingKey: the routing key to use. If not provided, the queue name will be used as the routing key.
    ///   - arguments: table with additional keys and values to be used when binding.
    ///  - Throws: if connection or this channel has been already closed or the broker responds with an error.
    public func queueBind(
        queue: String,
        exchange: String,
        routingKey: String? = nil,
        arguments: Spec.Table = .init()
    ) async throws {
        let method = Spec.Queue.Bind(
            ticket: 0,
            queue: queue,
            exchange: exchange,
            routingKey: routingKey ?? queue,
            nowait: false,
            arguments: arguments
        )
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Queue.BindOk,
            "queueBind expects Spec.Queue.BindOk but got \(String(describing: frame)))"
        )
    }

    // asks broker to bind the queue to exchange doesn't wait for a response from the broker, but let broker to raise exception if the binding didn't work.
    /// - Parameters:
    ///   - queue: the name of the queue.
    ///   - exchange: the name of the exchange.
    ///   - routingKey: the routing key to use. If not provided, the queue name will be used as the routing key.
    ///   - arguments: table with additional keys and values to be used when binding.
    ///  - Throws: if connection or this channel has been already closed.
    public func queueBindNoWait(
        queue: String,
        exchange: String,
        routingKey: String? = nil,
        arguments: Spec.Table = .init()
    ) throws {
        let method = Spec.Queue.Bind(
            ticket: 0,
            queue: queue,
            exchange: exchange,
            routingKey: routingKey ?? queue,
            nowait: true,
            arguments: arguments
        )
        let frame = makeFrame(with: method)
        try withConnection {
            $0.sendAsync(frame)
        }
    }

    public func basicPublish(
        exchange: String,
        routingKey: String,
        body: String,
        properties: Spec.BasicProperties = .init(),
        mandatory: Bool = false
    ) async throws {
        let method = Spec.Basic.Publish(exchange: exchange, routingKey: routingKey, mandatory: mandatory)
        let frame = makeFrame(with: method)
        let contentHeaderFrame = ContentHeaderFrame(
            channelId: self.id,
            classId: method.amqpClassId,
            bodySize: UInt64(body.utf8.count),
            properties: properties
        )
        var framesToPublish: [any Frame] = [frame, contentHeaderFrame]
        if body.utf8.count > self.maxFragmentSize {
            forEachChunk(
                of: body.utf8,
                maxChunkSize: Int(self.maxFragmentSize),
                perform: {
                    framesToPublish.append(
                        ContentBodyFrame(
                            channelId: self.id,
                            fragment: .init($0)
                        )
                    )
                }
            )
        } else {
            framesToPublish.append(
                ContentBodyFrame(
                    channelId: self.id,
                    fragment: .init(body.utf8)
                )
            )
        }
        try withConnection {
            $0.sendAsync(framesToPublish)
        }
    }

    public func basicConsume(
        queue: String,
        autoAck: Bool = false,
        tag: String = "",
        noLocal: Bool = false,
        exclusive: Bool = false,
        arguments: Spec.Table = .init()
    ) async throws -> AsyncThrowingStream<Message, Error> {
        let method = Spec.Basic.Consume(
            queue: queue,
            consumerTag: tag,
            noLocal: noLocal,
            noAck: autoAck,
            exclusive: exclusive,
            nowait: false,
            arguments: arguments
        )
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
    ///  - Throws: if connection or this channel has been already closed.
    public func basicAck(deliveryTag: Int64, multiple: Bool = false) async throws {
        let method = Spec.Basic.Ack(deliveryTag: deliveryTag, multiple: multiple)
        let frame = makeFrame(with: method)
        try withConnection {
            $0.sendAsync(frame)
        }
    }

    /// Sends nack for one or more messages on this channel.
    /// - Parameters:
    ///   - deliveryTag: the delivery tag of the message to reject.
    ///   - multiple: if true, rejects all messages up to and including this one.
    ///   - requeue: if true, the message will be requeued.
    ///  - Throws: if connection or this channel has been already closed.
    public func basicNack(deliveryTag: Int64, multiple: Bool = false, requeue: Bool = true)
        async throws
    {
        let method = Spec.Basic.Nack(
            deliveryTag: deliveryTag,
            multiple: multiple,
            requeue: requeue
        )
        let frame = makeFrame(with: method)
        try withConnection {
            $0.sendAsync(frame)
        }
    }

    /// Communicates to broker to open this channel, doesn't check for isOpen status and always does the communication.
    internal func requestOpen() async throws {
        let method = Spec.Channel.Open()
        let frame = try await sendReturningResponse(method: method)
        precondition(
            frame?.payload is Spec.Channel.OpenOk,
            "Channel.requestOpen expects Spec.Channel.OpenOk but got \(String(describing: frame))"
        )
    }

    // this will communicate to broker to open this channel, it is called
    // automatically by the init, calling it again has no effect, but it allows
    // to reopen closed channel
    public func open() async throws {
        let res = self.state.compareExchange(expected: .closed, desired: .opening, ordering: .acquiringAndReleasing)
        if !res.exchanged {
            return
        }
        do {
            try await requestOpen()
            self.state.store(.open, ordering: .releasing)
        } catch {
            self.state.store(.closed, ordering: .releasing)
            throw error
        }
    }

    public func close(replyCode: UInt16 = 0, replyText: String = "") async throws {
        let method = Spec.Channel.Close(
            replyCode: replyCode,
            replyText: replyText,
            classId: 0,
            methodId: 0
        )
        let res = self.state.compareExchange(expected: .open, desired: .closing, ordering: .acquiringAndReleasing)
        if !res.exchanged {  // can only close open channel
            return
        }
        // the state may become inconsistent if this throws, but if it does it is probably a larger problem anyway
        let promise = try promises.withLockedValue {
            let promise = try withConnectionUnchecked {
                $0.send(makeFrame(with: method))
            }
            $0.append(promise)
            return promise
        }
        let frame = try await promise.futureResult.get() as? MethodFrame
        precondition(
            frame?.payload is Spec.Channel.CloseOk,
            "close expects Spec.Channel.CloseOk but got \(String(describing: frame))"
        )
        self.state.store(.closed, ordering: .releasing)
    }
}
