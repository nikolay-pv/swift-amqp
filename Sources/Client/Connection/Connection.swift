import Logging

internal let defaultCapabilities: Spec.FieldValue = .table([
    "authentication_failure_close": .bool(true),
    "basic.nack": .bool(true),
    "connection.blocked": .bool(true),
    "consumer_cancel_notify": .bool(true),
    "publisher_confirms": .bool(true),
])

internal let defaultProperties: [String: Spec.FieldValue] = [
    "product": .longstr("AMQP 0.9.1 Client"),
    "platform": .longstr("swift"),
    // "version": .longstr("0.1.0"),
    // "information": .longstr("link to docs"),
    "capabilities": defaultCapabilities,
]

public final class Connection: Sendable {
    private let logger: Logger
    // MARK: - transport management
    private let transport: TransportProtocol

    private let inboundFramesDispatcher: Task<Void, Never>

    // MARK: - channel management
    private let channels: ChannelManager

    // throw ConnectionError.connectionIsClosed if connection is closed
    // throw ConnectionError.maxChannelsLimitReached if no more channels can be created
    public func makeChannel() async throws -> Channel {
        try ensureOpen()
        let channel = try channels.makeChannel(transport: self.transport, logger: self.logger)
        try await channel.requestOpen()
        return channel
    }

    // MARK: - lifecycle management
    public var isOpen: Bool { transport.isActive }

    public func close() async throws {
        try await self.channels.channel0.connectionClose()
        // from now on no more frames will be sent out
        transport.stop()
    }

    private func ensureOpen() throws {
        if !isOpen {
            throw ConnectionError.connectionIsClosed
        }
    }

    // MARK: - init
    public convenience init(
        with configuration: Configuration = .default,
        andProperties properties: Spec.Table = .init()
    ) async throws {
        try await self.init(with: configuration, env: Environment.shared, properties: properties)
    }

    // swiftlint:disable:next function_body_length
    init(with configuration: Configuration, env: Environment, properties: Spec.Table = .init())
        async throws
    {
        // extend the default properties with user-provided ones
        let properties = defaultProperties.merging(properties) { _, new in new }

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
        let sharedTransport = try await env.transportFactory(
            configuration.host,
            configuration.port,
            configuration.logger,
            inboundContinuation,
            {
                return env.negotiationFactory(configuration, properties)
            }
        )

        let (negotiatedConfig, _) = sharedTransport.negotiatedProperties
        let channels: ChannelManager = .init(
            transport: sharedTransport,
            logger: configuration.logger,
            maxChannels: negotiatedConfig.maxChannelCount
        )

        self.logger = configuration.logger
        self.transport = sharedTransport
        self.channels = channels
        // create a task to distribute incoming frames
        self.inboundFramesDispatcher = Task {
            await Connection.routingLoop(inboundFrames: inboundFrames, channels: channels)
            sharedTransport.stop()
        }
    }

    static func routingLoop(inboundFrames: AsyncStream<any Frame>, channels: ChannelManager) async {
        for await frame in inboundFrames {
            guard let channel = channels.findChannel(id: frame.channelId) else {
                preconditionFailure(
                    "Received frame for non-existing channel \(frame.channelId)"
                )
            }
            let res = channel.dispatch(frame: frame)
            switch res {
            case .failure:
                channels.forEach {
                    $0.handleConnectionError(ConnectionError.connectionIsClosed)
                }
            case .success(let keepGoing):
                if keepGoing {
                    continue
                }
            }
            break  // stop processing any further frames
        }
    }

    deinit {
        transport.stop()
        inboundFramesDispatcher.cancel()
    }
}
