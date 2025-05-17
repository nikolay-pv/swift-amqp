import Collections

public actor Channel {
    public let id: UInt16
    private weak var connection: Connection?
    private var continuation: AsyncStream<Frame>.Continuation?
    private lazy var responses: AsyncStream<Frame> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    public func exchangeDeclare(named exchangeName: String) async throws {
        let method = Spec.Exchange.Declare(exchange: exchangeName)
        try await send(method: method)
        // make sure DeclareOk came back
        _ = await responses.first(where: {
            guard let frame = $0 as? MethodFrame else { return false }
            return frame.payload is Spec.Exchange.DeclareOk
        })
    }

    public func queueDeclare(named queueName: String) async throws {
        let method = Spec.Queue.Declare(queue: queueName)
        try await send(method: method)
        let response = await responses.first(where: {
            guard let frame = $0 as? MethodFrame else { return false }
            return frame.payload is Spec.Queue.DeclareOk
        })
        print("\(response)")
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

        guard let connection = self.connection else {
            throw ConnectionError.connectionIsClosed
        }
        try await connection.send(frames: [frame, contentHeaderFrame, contentFrame])
    }

    internal func requestOpen() async throws {
        let method = Spec.Channel.Open()
        try await send(method: method)

        let response = await responses.first(where: {
            guard let frame = $0 as? MethodFrame else { return false }
            return frame.payload is Spec.Channel.OpenOk
        })
        // TODO: make sure the name is used if wasn't requested
        print("\(response)")
    }

    // MARK: - init
    internal init(connection: Connection, id: UInt16) {
        self.id = id
        self.connection = connection
    }
}

extension Channel {
    fileprivate func send(
        method: some AMQPMethodProtocol & FrameCodable
    ) async throws {
        let frame = MethodFrame(channelId: id, payload: method)
        guard let connection = self.connection else {
            throw ConnectionError.connectionIsClosed
        }
        try await connection.send(frame: frame)
    }

    fileprivate func handleIncoming(frame: Frame) {
        self.continuation?.yield(frame)
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

    func send(frame: Frame) async throws {
        try await transport.send(frame: frame)
    }

    func send(frames: [Frame]) async throws {
        try await transport.send(frames: frames)
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
        transportExecutor = Task { [weak self, unowned transport] in
            try? await transport.execute { [weak self] frame in
                let id = frame.channelId
                await self?.channels[id]?.handleIncoming(frame: frame)
            }
        }
    }

    deinit {
        transportExecutor?.cancel()
    }
}
