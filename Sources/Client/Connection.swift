import Collections
import Logging
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
    private var logger: Logger
    // MARK: - transport management
    private var transportExecutor: Task<Void?, Never>?

    private let outboundContinuation: AsyncStream<any Frame>.Continuation
    private var inboundFramesDispatcher: Task<Void?, Never>?

    func send(frame: any Frame) {
        if isOpen {
            outboundContinuation.yield(frame)
        }
    }

    func send(frames: [any Frame]) {
        if isOpen {
            frames.forEach { outboundContinuation.yield($0) }
        }
    }

    private func handleChannel0(frame: any Frame) async {
        guard let frame = frame as? MethodFrame else {
            preconditionFailure("Unexpected frame type in channel 0: \(type(of: frame))")
        }
        if frame.payload as? Spec.Connection.CloseOk != nil {
            await self.channel0.dispatch(frame: frame)
            return
        }
        if let payload = frame.payload as? Spec.Connection.Close {
            // eat exceptions as it doesn't make sense to throw here (broker already closed the connection)
            try? await self.channel0.connectionCloseOk()
            isOpen = false
            transportExecutor?.cancel()
            if payload.replyCode != 0 {
                logger.error(
                    "Connection closed by broker with code \(payload.replyCode): \(payload.replyText)"
                )
                for channel in channels.values {
                    await channel.handleConnectionError(ConnectionError.connectionIsClosed)
                }
            }
            return
        }
        fatalError("unreachable: in handleChannel0 with frame \(frame)")
    }

    // MARK: - channel management
    // channel0 is special and is used for communications before any channel exists
    // it never explicitly created on the server side (so no requestOpen call is made for it)
    private lazy var channel0: Channel = { Channel(connection: self, id: 0, logger: self.logger) }()
    private var channels: [UInt16: Channel] = [:]
    private var channelIDs: ChannelIDs = .init()

    public func makeChannel() async throws -> Channel {
        try ensureOpen()
        let id = UInt16(channelIDs.next())
        let channel = Channel.init(connection: self, id: id, logger: self.logger)
        channels[id] = channel
        try await channel.requestOpen()
        return channel
    }

    // MARK: - lifecycle management
    private(set) var isOpen: Bool = true

    public func close() async throws {
        try await self.channel0.connectionClose()
        // from now on no more frames will be sent out
        isOpen = false
        transportExecutor?.cancel()
    }

    private func ensureOpen() throws {
        if !isOpen {
            throw ConnectionError.connectionIsClosed
        }
    }

    // MARK: - init
    public init(with configuration: Configuration = .default) async throws {
        try await self.init(with: configuration, env: Environment.shared)
    }

    // swiftlint:disable:next function_body_length
    init(with configuration: Configuration, env: Environment) async throws {
        self.logger = configuration.logger
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
        var inboundContinuation: AsyncStream<any Frame>.Continuation?
        let inboundFrames = AsyncStream { continuation in
            inboundContinuation = continuation
        }
        guard let inboundContinuation else {
            fatalError("Couldn't create inbound AsyncStream")
        }

        // create outbound AsyncStream
        var outboundContinuation: AsyncStream<any Frame>.Continuation?
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
        isOpen = true
        let transport: any TransportProtocol & ~Copyable
        let transportLogger = self.logger
        do {
            transport = try await env.transportFactory(
                configuration.host,
                configuration.port,
                transportLogger,
                inboundContinuation,
                outboundFrames,
                {
                    return env.negotiationFactory(configuration, properties)
                }
            )
        } catch {
            isOpen = false
            throw error
        }
        self.transportExecutor = Task {
            await transport.execute()
        }

        // create a task to distribute incoming frames
        self.inboundFramesDispatcher = Task {
            for await frame in inboundFrames {
                let channelId = frame.channelId
                if channelId == 0 {
                    await self.handleChannel0(frame: frame)
                } else {
                    await self.channels[channelId]?.dispatch(frame: frame)
                }
            }
        }
    }

    deinit {
        transportExecutor?.cancel()
        inboundFramesDispatcher?.cancel()
    }
}
