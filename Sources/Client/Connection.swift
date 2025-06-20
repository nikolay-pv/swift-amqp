import Collections
import NIOCore
import NIOPosix

///
/// @note Channel can't outlive the Connection which made it
public actor Channel {
    public let id: UInt16
    private unowned var connection: Connection
    private var promises: [EventLoopPromise<Frame>] = .init()
    private let eventLoop: EventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()

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

    // MARK: - init
    internal init(connection: Connection, id: UInt16) {
        self.id = id
        self.connection = connection
    }
}

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

    internal func dispatch(frame: Frame) {
        // ideally will handle other frames too, but for now only ones it expects
        guard !promises.isEmpty else {
            return
        }
        precondition(!promises.isEmpty, "channel got an unexpected frame")
        let promise = promises.removeFirst()
        promise.succeed(frame)
    }
}

struct ChannelIDs {
    private var nextFree: Int = 1
    private var occupied: OrderedSet<Int> = []
    private var freed: OrderedSet<Int> = []

    func isFree(_ id: Int) -> Bool { !occupied.contains(id) && nextFree <= id }

    mutating func remove(id: Int) {
        if id == nextFree - 1 {
            nextFree -= 1
        } else {
            // TODO: this does linear search -> find faster DS
            freed.insert(id, at: occupied.firstIndex(where: { $0 >= id }) ?? occupied.endIndex)
        }
        occupied.remove(id)
    }

    mutating func next() -> Int {
        if !freed.isEmpty {
            let id = freed.removeFirst()
            return id
        }
        let id = nextFree
        nextFree += 1
        return id
    }
}

public actor Connection {
    // MARK: - transport management
    private let transport: Transport
    private var transportExecutor: Task<Void?, Never>?

    private let serverFrames: AsyncStream<Frame>
    private var serverFramesDispatcher: Task<Void?, Never>?

    func send(frame: Frame) {
        transport.send(frame: frame)
    }

    func send(frames: [Frame]) {
        transport.send(frames: frames)
    }

    // MARK: - channel management
    // channel0 is special and is used for communications before any channel exists
    // it never explicitly created on the server side (so no requestOpen call is made for it)
    private lazy var channel0: Channel = { Channel(connection: self, id: 0) }()
    private var channels: [UInt16: Channel] = [:]
    private var channelIDs: ChannelIDs = .init()

    public func makeChannel() async throws -> Channel {
        try ensureOpen()
        let id = UInt16(channelIDs.next())
        let channel = Channel.init(connection: self, id: id)
        channels[id] = channel
        try await channel.requestOpen()
        return channel
    }

    // MARK: - lifecycle management
    private var closed: Bool = false

    public func close() {
        closed = false
    }

    public func blockingClose() {
        closed = false
    }

    private func ensureOpen() throws {
        guard !closed else {
            throw ConnectionError.connectionIsClosed
        }
    }

    // MARK: - init
    public init(with configuration: Configuration = .default) async throws {
        let properties: Spec.Table = [
            "product": .longstr("swift-amqp"),
            "platform": .longstr("swift"),
            "capabilities": .table([
                "authentication_failure_close": .bool(true),
                "basic.nack": .bool(true),
                "connection.blocked": .bool(true),
                "consumer_cancel_notify": .bool(true),
                "publisher_confirms": .bool(true),
            ]),
            "information": .longstr("website here"),
        ]
        let transport = try await Transport(
            host: configuration.host,
            port: configuration.port,
            negotiatorFactory: {
                return Spec.AMQPNegotiator(config: configuration, properties: properties)
            }
        )
        self.transport = transport
        var serverContinuation: AsyncStream<Frame>.Continuation? = nil
        self.serverFrames = AsyncStream { continuation in
            serverContinuation = continuation
        }
        transportExecutor = Task {
            guard let serverContinuation else { return }
            try? await self.transport.execute(serverContinuation)
        }
        serverFramesDispatcher = Task {
            for await frame in self.serverFrames {
                let channelId = frame.channelId
                await channels[channelId]?.dispatch(frame: frame)
            }
        }
    }

    deinit {
        transportExecutor?.cancel()
        transportExecutor = nil
        serverFramesDispatcher?.cancel()
        serverFramesDispatcher = nil
    }
}
