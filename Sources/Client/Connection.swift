import Collections
import Logging
import NIOConcurrencyHelpers
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

struct ContentContext {
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

public final class Connection: @unchecked Sendable {
    private let logger: Logger
    // MARK: - transport management
    private let transport: TransportProtocol
    private let transportExecutor: Task<Void?, Never>

    private var inboundFramesDispatcher: Task<Void?, Never>?

    private func handleChannel0(frame: any Frame) async {
        guard let frame = frame as? MethodFrame else {
            preconditionFailure("Unexpected frame type in channel 0: \(type(of: frame))")
        }
        if frame.payload as? Spec.Connection.CloseOk != nil {
            self.channel0.dispatch(frame: frame)
            return
        }
        if let payload = frame.payload as? Spec.Connection.Close {
            // eat exceptions as it doesn't make sense to throw here (broker already closed the connection)
            self.channel0.connectionCloseOk()
            transportExecutor.cancel()
            if payload.replyCode != 0 {
                logger.error(
                    "Connection closed by broker with code \(payload.replyCode): \(payload.replyText)"
                )
                for channel in channels.values {
                    channel.handleConnectionError(ConnectionError.connectionIsClosed)
                }
            }
            return
        }
        fatalError("unreachable: in handleChannel0 with frame \(frame)")
    }

    // MARK: - channel management
    // channel0 is special and is used for communications before any channel exists
    // it never explicitly created on the server side (so no requestOpen call is made for it)
    private let channel0: Channel

    private let channelsLock = NIOLock()
    private var channels: [UInt16: Channel] = [:]
    private var channelIDs: ChannelIDs = .init()

    public func makeChannel() async throws -> Channel {
        try ensureOpen()
        let channel: Channel = channelsLock.withLock {
            let id = UInt16(channelIDs.next())
            let channel = Channel.init(transport: self.transport, id: id, logger: self.logger)
            channels[id] = channel
            return channel
        }
        try await channel.requestOpen()
        return channel
    }

    // MARK: - lifecycle management
    public var isOpen: Bool { transport.isActive }

    public func close() async throws {
        try await self.channel0.connectionClose()
        // from now on no more frames will be sent out
        transportExecutor.cancel()
    }

    private func ensureOpen() throws {
        if !isOpen {
            throw ConnectionError.connectionIsClosed
        }
    }

    // MARK: - init
    public convenience init(with configuration: Configuration = .default) async throws {
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

        // hand both AsyncStreams to Transport for communication
        // and then start receiving & sending frames
        self.transport = try await env.transportFactory(
            configuration.host,
            configuration.port,
            self.logger,
            inboundContinuation,
            {
                return env.negotiationFactory(configuration, properties)
            }
        )
        let sharedTransport = self.transport
        self.transportExecutor = Task {
            await sharedTransport.execute()
        }

        self.channel0 = .init(transport: sharedTransport, id: 0, logger: self.logger)

        // create a task to distribute incoming frames
        self.inboundFramesDispatcher = Task {
            var contentContext = ContentContext()
            for await frame in inboundFrames {
                if let methodFrame = frame as? MethodFrame,
                    methodFrame.payload as? Spec.Basic.Deliver != nil
                {
                    contentContext.push(deliver: frame)
                    continue
                }
                if isContent(frame) {
                    guard contentContext.waitForContent() else {
                        preconditionFailure(
                            "Received content frame without prior deliver method"
                        )
                    }
                    if let header = frame as? ContentHeaderFrame {
                        contentContext.push(header: header)
                        continue
                    }
                    if let body = frame as? ContentBodyFrame {
                        contentContext.push(body: body)
                    }
                    if contentContext.isComplete() {
                        let channel: Channel? = self.channelsLock.withLock {
                            return self.channels[contentContext.channelId]
                        }
                        channel?.dispatch(content: contentContext.contentFrames)
                        contentContext.reset()
                    }
                    continue
                }
                let channelId = frame.channelId
                if channelId == 0 {
                    await self.handleChannel0(frame: frame)
                } else {
                    let channel: Channel? = self.channelsLock.withLock {
                        return self.channels[channelId]
                    }
                    // TODO: receiving frame for non-existing channel is probably a protocol violation
                    channel?.dispatch(frame: frame)
                }
            }
        }
    }

    deinit {
        transportExecutor.cancel()
        inboundFramesDispatcher?.cancel()
    }
}
