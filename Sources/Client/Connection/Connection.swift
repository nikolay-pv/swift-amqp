import Atomics
import Logging
import NIOConcurrencyHelpers
import NIOCore

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

    // MARK: - channel management
    private let channels: ChannelManager
    // promise to handle async close
    private let closingPromise: NIOLockedValueBox<EventLoopPromise<any Frame>?> = .init(nil)

    // throw ConnectionError.connectionIsClosed if connection is closed
    // throw ConnectionError.maxChannelsLimitReached if no more channels can be created
    public func makeChannel() async throws -> Channel {
        try ensureOpen()
        let channel = try channels.makeChannel(
            connection: self,
            maxFrameSize: self.transport.negotiatedProperties.0.maxFrameSize,
            logger: self.logger
        )
        try await channel.requestOpen()
        return channel
    }

    // MARK: - lifecycle management
    private let state: ManagedAtomic<ObjectState> = .init(.open)
    private let closingError: NIOLockedValueBox<ConnectionError?> = .init(nil)
    public var isOpen: Bool { transport.isActive && self.state.load(ordering: .acquiring) == .open }

    public func close() async throws {
        try await self.closeHandshake()
    }

    internal func ensureOpen() throws {
        if !isOpen {
            // if connection was closed with an error, throw that one
            let error = self.closingError.withLockedValue { $0 } ?? ConnectionError.connectionIsClosed
            throw error
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
        var inboundContinuation: AsyncStream<TransportEvent>.Continuation?
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
        let channels: ChannelManager = .init(maxChannels: negotiatedConfig.maxChannelCount)

        self.logger = configuration.logger
        self.transport = sharedTransport
        self.channels = channels

        // create a task to distribute incoming frames
        Task.detached {
            await Connection.routingLoop(
                inboundFrames: inboundFrames,
                channels: channels,
                connection: self,
            )
            sharedTransport.stop()
        }
    }

    static func routingLoop(
        inboundFrames: AsyncStream<TransportEvent>,
        channels: ChannelManager,
        connection: Connection
    ) async {
        in_for: for await event in inboundFrames {
            if case .error(let error) = event {
                switch error {
                case .unexpectedNonzeroChannelId(let classId, let methodId):
                    // if the channel id is non-zero, the connection should be closed with an error
                    connection.initiateClose(
                        replyCode: Spec.HardError.commandInvalid.rawValue,
                        replyText: "",
                        classId: classId,
                        methodId: methodId
                    )
                    continue in_for  // process incoming frames until broker returns CloseOK
                case .invalidFrame:
                    connection.initiateClose(
                        replyCode: Spec.HardError.frameError.rawValue,
                        replyText: "",
                        classId: 0,
                        methodId: 0
                    )
                    continue in_for  // process incoming frames until broker returns CloseOK
                default:
                    // if decoding fails due to invalid frame end or unknown
                    // frame type, the client SHOULD write a log message and
                    // close the connection (see 4.2.3. General Frame Format)
                    connection.logger.error("Breaking TCP connection due to framing error: \(error)")
                    connection.drop()
                    break in_for  // stop processing any further frames
                }
            } else if case .frame(let frame) = event {
                if frame.channelId == 0 {
                    if !connection.dispatch(frame) {
                        break  // stop processing any further frames
                    }
                    continue
                }
                guard let channel = channels.findChannel(id: frame.channelId) else {
                    preconditionFailure("Received frame for non-existing channel \(frame.channelId)")
                }
                channel.dispatch(frame: frame)
                continue
            }
        }
    }

    deinit {
        precondition(
            self.state.load(ordering: .acquiring) == .closed,
            "close() wasn't called on this connection object, which is required by the protocol"
        )
    }
}

extension Connection {
    func send(_ frame: any Frame) -> EventLoopPromise<any Frame> {
        self.transport.send(frame)
    }

    func sendAsync(_ frame: any Frame) {
        self.transport.sendAsync(frame)
    }
}

extension Connection {
    // returns true if the future frames should still be processed and false if
    // they shouldn't
    private func dispatch(_ frame: any Frame) -> Bool {
        precondition(frame.channelId == 0, "dispatch0 called with non-zero channel id")
        if frame.isContent() {
            // 4.2.6.1 The channel number in content frames MUST NOT be zero.
            initiateClose(
                replyCode: Spec.HardError.channelError.rawValue,
                replyText: "Received content frame on channel 0",
                classId: 60,
                methodId: 0
            )
            return true
        }
        precondition(frame is MethodFrame, "Unexpected frame type in channel 0: \(type(of: frame))")
        if frame.isPayload(of: Spec.Connection.CloseOk.self) {
            // first propagate any connection error to channels and set final state
            let error = self.closingError.withLockedValue { $0 }
            self.channels.forEach {
                $0.handleConnectionCloseOk(error)
            }
            self.state.store(.closed, ordering: .releasing)
            // then fulfill the closing promise so callers waiting on closeHandshake
            // observe that connection and channels are already closed
            self.closingPromise.withLockedValue {
                $0?.succeed(frame)
                // reset the fulfilled promise so it is not used again
                $0 = nil
            }
            return false
        }
        if let payload = frame.unwrapPayload(as: Spec.Connection.Close.self) {
            self.sendCloseOk()
            if payload.replyCode != 0 && payload.replyCode != 200 {
                guard let code = Spec.HardError(rawValue: payload.replyCode) else {
                    fatalError(
                        "Broker sent unknown error reply code in Connection.Close frame: \(payload.replyCode) with message \(payload.replyText)"
                    )
                }
                let error = HardError.broker(
                    code: code,
                    replyText: payload.replyText,
                    classId: payload.amqpClassId,
                    methodId: payload.amqpMethodId
                )
                self.closingError.withLockedValue {
                    $0 = ConnectionError.wrap(hardError: error)
                }
            }
            return false
        }
        fatalError("unreachable: in Connection.dispatch with frame \(frame)")
    }

    // drops connection immediately without a handshake, used to react to fatal protocol violations
    private func drop() {
        self.state.store(.closed, ordering: .releasing)
        self.transport.drop()
    }

    // does nothing if the state is not .open or if transport is not active
    private func closeHandshake(
        replyCode: UInt16 = 0,
        replyText: String = "",
        classId: UInt16 = 0,
        methodId: UInt16 = 0
    ) async throws {
        let res = self.state.compareExchange(expected: .open, desired: .closing, ordering: .acquiringAndReleasing)
        if !res.exchanged {
            return
        }
        let method = Spec.Connection.Close(
            replyCode: replyCode,
            replyText: replyText,
            classId: classId,
            methodId: methodId
        )
        let frame = MethodFrame(channelId: 0, payload: method)
        let promise = closingPromise.withLockedValue {
            let promise = transport.send(frame)
            $0 = promise
            return promise
        }
        defer {  // even if future throws ensure final state
            self.state.store(.closed, ordering: .releasing)
        }
        _ = try await promise.futureResult.get()
    }

    internal func initiateClose(
        replyCode: UInt16 = 0,
        replyText: String = "",
        classId: UInt16 = 0,
        methodId: UInt16 = 0
    ) {
        let res = self.state.compareExchange(expected: .open, desired: .closing, ordering: .acquiringAndReleasing)
        if !res.exchanged {
            return
        }
        let method = Spec.Connection.Close(
            replyCode: replyCode,
            replyText: replyText,
            classId: classId,
            methodId: methodId
        )
        if replyCode != 0 && replyCode != 200 {
            let code = Spec.HardError(rawValue: replyCode)
            precondition(code != nil)
            let error = HardError.client(code: code!, replyText: replyText, classId: classId, methodId: methodId)
            self.closingError.withLockedValue {
                $0 = ConnectionError.wrap(hardError: error)
            }
        }
        let frame = MethodFrame(channelId: 0, payload: method)
        self.transport.sendAsync(frame)
    }

    private func sendCloseOk() {
        self.state.store(.closing, ordering: .releasing)
        let method = Spec.Connection.CloseOk()
        let frame = MethodFrame(channelId: 0, payload: method)
        transport.sendAsync(frame)
        self.state.store(.closed, ordering: .releasing)
    }
}
