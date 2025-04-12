import Collections

//protocol AMQPConnectionDelegate {
//    func connectionDidClose(_ connection: AMQPConnection) async
//    func connectionDidOpen(_ connection: AMQPConnection) async
//}
//
//// RMQ extension
//protocol RMQConnectionDelegate: AMQPConnectionDelegate {
//    func connectionDidBlock(_ connection: AMQPConnection) async
//    func connectionDidUnblock(_ connection: AMQPConnection) async
//}

public actor Channel {
    init(id: Int) async {
        self.id = id
    }

    private(set) var id: Int
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
            // TODO: this does lienear search -> find faster DS
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
    private var transport: Transport
    private var closed: Bool = false

    public func close() {
        // TODO: implement this properly
        closed = false
    }

    public func blockingClose() {
        // TODO: implement this properly
        closed = false
    }

    // MARK: - channel management
    private var channel0: Channel
    private var channels: [Int: Channel] = [:]
    private var channelIDs: ChannelIDs = .init()

    public func makeChannel() async throws -> Channel {
        try ensureOpen()
        let id = channelIDs.next()
        let channel = await Channel.init(id: id)
        return channel
    }

    // MARK: - private methods
    private func ensureOpen() throws {
        guard !closed else {
            throw ConnectionError.connectionIsClosed
        }
    }

    // MARK: - init
    public init(with configuration: AMQPConfiguration = .default) async throws {
        channel0 = await Channel(id: 0)
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
        transport = try await Transport(host: configuration.host, port: configuration.port) {
            return Spec.AMQPNegotiator(config: configuration, properties: properties)
        }
    }
}
