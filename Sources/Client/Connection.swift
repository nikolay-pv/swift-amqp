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

public actor AMQPChannel {
    init(id: Int) {
        self.id = id
    }

    private(set) var id: Int

    func open() async throws {

    }
}

enum AMQPConnectionError: Error {
    case unexpectedState(actual: Connection.State, expected: Connection.State)
    case handshakeFailed(reason: String)
}

enum AMQPChannelError: Error {
    case idAlreadyInUse
}

struct ChannelIDs {
    private var nextFree: Int = 0
    private var occupied: OrderedSet<Int> = []
    private var freed: OrderedSet<Int> = []

    func isFree(_ id: Int) -> Bool { !occupied.contains(id) && nextFree <= id }

    // returns the same id if insertion was successful
    mutating func add(id: Int) throws -> Int {
        guard isFree(id) else { throw AMQPChannelError.idAlreadyInUse }
        if id == nextFree {
            nextFree += 1
        } else if id > nextFree {
            // TODO: this does lienear search -> find faster DS
            occupied.insert(id, at: occupied.firstIndex(where: { $0 >= id }) ?? occupied.endIndex)
        }
        freed.remove(id)
        return id
    }

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
    // MARK: - init
    public init(with configuration: AMQPConfiguration = .default) async {
        // transport = FakeAMQPTransport()
        channel0 = AMQPChannel(id: 0)
        // todo: fix the force unwrap
        try! await start()
    }

    deinit {
        // TODO: close here
    }

    // MARK: - state management
    public enum State: String, Sendable {
        case closed
        case handshake
        case open
        case closing

        var isOpen: Bool { self == .open }
        var isClosed: Bool { self == .closed }
        var isClosing: Bool { self == .closing }
    }
    public private(set) var state: State = .closed

    // MARK: - connection management
    // var transport: AMQPTransportProtocol

    public var isOpen: Bool { return state == .open }

    func start() async throws {
        guard state.isClosed else {
            throw AMQPConnectionError.unexpectedState(actual: state, expected: .closed)
        }
        // try transport.connect()
        // do a sequence here
        state = .handshake
        // start
        // tune
        // open
        state = .open
    }

    func close() {}
    func blockingClose() {}

    // MARK: - channel management

    private var channel0: AMQPChannel
    private var channels: [Int: AMQPChannel] = [:]
    private var channelIDs: ChannelIDs = .init()

    func makeChannel(id: Int?) async throws -> AMQPChannel {
        guard isOpen else {
            throw AMQPConnectionError.unexpectedState(actual: state, expected: .open)
        }
        // will throw if id is already occupied
        let id = id == nil ? channelIDs.next() : try channelIDs.add(id: id!)
        let channel = AMQPChannel.init(id: id)
        // TODO: or force the client to call open so they get the feedback on it themselves
        try await channel.open()
        return channel
    }

}
