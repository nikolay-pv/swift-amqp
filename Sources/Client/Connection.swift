import Collections
import NIOCore
import NIOPosix

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
    private var transportExecutor: Task<Void?, Never>

    private let outboundContinuation: AsyncStream<Frame>.Continuation
    private var inboundFramesDispatcher: Task<Void?, Never>!

    func send(frame: Frame) {
        outboundContinuation.yield(frame)
    }

    func send(frames: [Frame]) {
        frames.forEach { outboundContinuation.yield($0) }
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
    private var closed: Bool = true

    public func close() {
        closed = true
    }

    public func blockingClose() {
        closed = true
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

        // create inbound AsyncStream
        var inboundContinuation: AsyncStream<Frame>.Continuation?
        let inboundFrames = AsyncStream { continuation in
            inboundContinuation = continuation
        }
        guard let inboundContinuation else {
            fatalError("Couldn't create inbound AsyncStream")
        }

        // create outbound AsyncStream
        var outboundContinuation: AsyncStream<Frame>.Continuation?
        let outboundFrames = AsyncStream { continuation in
            outboundContinuation = continuation
        }
        guard let outboundContinuation else {
            fatalError("Couldn't create outbound AsyncStream")
        }
        // save continuation for later use
        self.outboundContinuation = outboundContinuation

        // hand both AsyncStreams to Transport for communication
        // and then start receiving & sending frames
        self.transportExecutor = Task {
            do {
                let transport = try await Environment.shared.transportFactory(
                    configuration.host,
                    configuration.port,
                    inboundContinuation,
                    outboundFrames,
                    {
                        return Environment.shared.negotiationFactory(configuration, properties)
                    }
                )
                try await transport.execute()
            } catch {
                fatalError("TODO: better messaging")
            }
        }
        self.closed = false

        // create a task to distribute incoming frames
        self.inboundFramesDispatcher = Task {
            for await frame in inboundFrames {
                let channelId = frame.channelId
                if channelId == 0 {
                    await self.channel0.dispatch(frame: frame)
                } else {
                    await self.channels[channelId]?.dispatch(frame: frame)
                }
            }
        }
    }

    deinit {
        transportExecutor.cancel()
        inboundFramesDispatcher.cancel()
    }
}
