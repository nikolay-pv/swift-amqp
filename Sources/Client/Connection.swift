import Collections

public actor Channel {
    public let id: UInt16
    private(set) weak var connection: Connection?
    private var continuation: AsyncStream<Frame>.Continuation?
    private lazy var responses: AsyncStream<Frame> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    func exchange_declare(named exchangeName: String) async throws {
        let method = Spec.Exchange.Declare(exchange: exchangeName)
        try await send(method: method, waitingFor: Spec.Exchange.DeclareOk())
    }

    func queue_declare(named queueName: String) async throws {
        let method = Spec.Queue.Declare(queue: queueName)
        try await send(
            method: method,
            waitingFor: Spec.Queue.DeclareOk(queue: queueName, messageCount: 0, consumerCount: 0)
        )
    }

    func basic_publish(exchange: String, routingKey: String, body: String) async throws {
        let method = Spec.Basic.Publish(exchange: exchange, routingKey: routingKey)
        let frame = MethodFrame(channelId: self.id, payload: method)
        let contnetProps = Spec.BasicProperties()
        let contentHeaderFrame = ContentHeaderFrame(
            channelId: self.id,
            classId: method.amqpClassId,
            bodySize: UInt64(body.utf8.count),
            properties: contnetProps
        )
        let contentFrame = ContentBodyFrame(channelId: self.id, fragment: [UInt8].init(body.utf8))

        guard let connection = self.connection else {
            throw ConnectionError.connectionIsClosed
        }
        try await connection.send(frame: frame)
        try await connection.send(frame: contentHeaderFrame)
        try await connection.send(frame: contentFrame)
    }

    func requestOpen() async throws {
        let method = Spec.Channel.Open()
        try await send(method: method, waitingFor: Spec.Channel.OpenOk())
    }

    // MARK: - init
    init(connection: Connection, id: UInt16) {
        self.id = id
        self.connection = connection
    }
}

extension Channel {
    fileprivate func send(
        method: some AMQPMethodProtocol & FrameCodable,
        waitingFor response: any AMQPMethodProtocol & FrameCodable
    ) async throws {
        let frame = MethodFrame(channelId: id, payload: method)
        guard let connection = self.connection else {
            throw ConnectionError.connectionIsClosed
        }
        try await connection.send(frame: frame)
        print("Channel with id \(id) waits for response: \(response)")
        let response = await responses.first(where: { [response] frame in
            guard let methodFrame = frame as? MethodFrame else {
                return false
            }
            guard let payload = methodFrame.payload as? AMQPMethodProtocol else {
                return false
            }
            return payload.amqpMethodId == response.amqpMethodId
                && payload.amqpClassId == response.amqpClassId
        })
        print("Channel with id \(id) got a frame:\n\t\(response)")
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
    private var closed: Bool = false
    private var transportExecutor: Task<Void?, Never>?

    public func close() {
        // TODO: implement this properly
        closed = false
    }

    public func blockingClose() {
        // TODO: implement this properly
        closed = false
    }

    // MARK: - channel management
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

    // MARK: - private methods
    private func ensureOpen() throws {
        guard !closed else {
            throw ConnectionError.connectionIsClosed
        }
    }

    // MARK: - init
    public init(with configuration: Configuration = .default) async throws {
        // TODO: make configurable
        let properties: Spec.Table = [
            "product": .longstr("swift-amqp"),
            "platform": .longstr("swift"),  // TODO: version here or something
            "capabilities": .table([
                "authentication_failure_close": .bool(true),
                "basic.nack": .bool(true),
                "connection.blocked": .bool(true),
                "consumer_cancel_notify": .bool(true),
                "publisher_confirms": .bool(true),
            ]),
            "information": .longstr("website here"),
            // TODO: "version":  of the library
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

// Methods to be used by Channel
extension Connection {
    func send(frame: Frame) async throws {
        try await transport.send(frame: frame)
    }

}
