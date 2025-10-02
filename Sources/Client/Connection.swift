import Logging

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
