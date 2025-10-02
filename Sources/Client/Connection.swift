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

// in charge of bookkeeping track of channels, allows making them and finding
// them by id, as well as removing them
final class ChannelManager: @unchecked Sendable {
    // channel0 is special and is used for communications before any channel exists
    // it never explicitly created on the server side (so no requestOpen call is made for it)
    let channel0: Channel

    private let channelsLock = NIOLock()
    private var channels: [UInt16: Channel] = [:]
    private var channelIDs: ChannelIDs = .init()

    func makeChannel(transport: TransportProtocol, logger: Logger) -> Channel {
        let channel: Channel = channelsLock.withLock {
            let id = UInt16(channelIDs.next())
            let channel = Channel.init(transport: transport, id: id, logger: logger)
            channels[id] = channel
            return channel
        }
        return channel
    }

    func removeChannel(id: UInt16) {
        channelsLock.withLock {
            precondition(channels.keys.contains(id), "Trying to destroy non-existing channel \(id)")
            channels.removeValue(forKey: id)
            channelIDs.remove(id: Int(id))
        }
    }

    func findChannel(id: UInt16) -> Channel? {
        if id == 0 {
            return channel0
        }
        return channelsLock.withLock {
            return channels[id]
        }
    }

    func broadcastConnectionError() {
        channelsLock.withLock {
            for channel in channels.values {
                channel.handleConnectionError(ConnectionError.connectionIsClosed)
            }
        }
    }

    // MARK: - init

    // initializes the channel0 with given transport and the logger
    init(transport: TransportProtocol, logger: Logger) {
        self.channel0 = .init(transport: transport, id: 0, logger: logger)
    }
}

public final class Connection: Sendable {
    private let logger: Logger
    // MARK: - transport management
    private let transport: TransportProtocol
    private let transportExecutor: Task<Void?, Never>

    private let inboundFramesDispatcher: Task<Void?, Never>

    // MARK: - channel management
    private let channels: ChannelManager

    public func makeChannel() async throws -> Channel {
        try ensureOpen()
        let channel = channels.makeChannel(transport: self.transport, logger: self.logger)
        try await channel.requestOpen()
        return channel
    }

    // MARK: - lifecycle management
    public var isOpen: Bool { transport.isActive }

    public func close() async throws {
        try await self.channels.channel0.connectionClose()
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

        self.channels = .init(transport: sharedTransport, logger: self.logger)

        // create a task to distribute incoming frames
        let sharedChannels = self.channels
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
                        guard let channel = sharedChannels.findChannel(id: frame.channelId) else {
                            preconditionFailure(
                                "Received frame for non-existing channel \(frame.channelId)"
                            )
                        }
                        channel.dispatch(content: contentContext.contentFrames)
                        contentContext.reset()
                    }
                    continue
                }
                guard let channel = sharedChannels.findChannel(id: frame.channelId) else {
                    preconditionFailure(
                        "Received frame for non-existing channel \(frame.channelId)"
                    )
                }
                let res = channel.dispatch(frame: frame)
                switch res {
                case .failure:
                    sharedChannels.broadcastConnectionError()
                case .success(let keepGoing):
                    guard keepGoing else {
                        break
                    }
                    continue
                }
                break  // stop processing any further frames
            }
        }
    }

    deinit {
        transportExecutor.cancel()
        inboundFramesDispatcher.cancel()
    }
}
