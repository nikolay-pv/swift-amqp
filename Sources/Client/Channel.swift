import NIOCore
import NIOPosix

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
    fileprivate func send(
        method: some AMQPMethodProtocol & FrameCodable,
        with promise: EventLoopPromise<Frame>?
    ) async throws {
        let frame = MethodFrame(channelId: id, payload: method)
        if let promise {
            promises.append(promise)
        }
        await connection.send(frame: frame)
    }

    public func exchangeDeclare(named exchangeName: String) async throws {
        let method = Spec.Exchange.Declare(exchange: exchangeName, durable: true)
        let promise = eventLoop.makePromise(of: Frame.self)
        try await send(method: method, with: promise)
        let frame = try await promise.futureResult.get() as? MethodFrame
        guard frame?.payload is Spec.Exchange.DeclareOk else {
            preconditionFailure(
                "exchangeDeclare expects Spec.Exchange.DeclareOk but got \(String(describing: frame))"
            )
        }
    }

    public func queueDeclare(named queueName: String) async throws -> Spec.Queue.DeclareOk {
        let method = Spec.Queue.Declare(queue: queueName, durable: true)
        let promise = eventLoop.makePromise(of: Frame.self)
        try await send(method: method, with: promise)
        let frame = try await promise.futureResult.get() as? MethodFrame
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
        let promise = eventLoop.makePromise(of: Frame.self)
        try await send(method: method, with: promise)
        let frame = try await promise.futureResult.get() as? MethodFrame
        guard frame?.payload is Spec.Queue.BindOk else {
            preconditionFailure(
                "queueDeclare expects Spec.Exchange.DeclareOk but got \(String(describing: frame))"
            )
        }
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
        let promise = eventLoop.makePromise(of: Frame.self)
        try await send(method: method, with: promise)
        let frame = try await promise.futureResult.get() as? MethodFrame
        guard frame?.payload is Spec.Channel.OpenOk else {
            preconditionFailure(
                "Channel.requestOpen expects Spec.Channel.OpenOk but got \(String(describing: frame))"
            )
        }
    }
}
