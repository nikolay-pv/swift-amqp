import AsyncAlgorithms

private struct ContentContext {
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

final class FramesRouter: Sendable {
    private let inboundFrames: AsyncStream<any Frame>
    private let channels: ChannelManager
    private let transportTask: Task<Void, Never>
    private let maxFrameSize: Int32

    func execute() async {
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
                    // only ContentBodyFrame is checked for maxFrameSize
                    // because there is no way to split other frames into smaller pieces
                    // see also: https://www.rabbitmq.com/amqp-0-9-1-errata#section_11
                    // check for exceeding expected body size
                    // as per "2.3.3 Protocol Negotiation"
                    // in case maxFrameSize is exceeded the connection must be
                    // closed
                    if maxFrameSize != 0 && body.bytesCount > UInt32(maxFrameSize) {
                        channels.forEach {
                            $0.handleConnectionError(
                                ConnectionError.frameSizeLimitExceeded(
                                    maxFrameSize: UInt32(maxFrameSize),
                                    actualSize: body.bytesCount
                                )
                            )
                        }
                        transportTask.cancel()  // drops the connection
                        break  // stop processing any further frames
                    }
                    contentContext.push(body: body)
                }
                if contentContext.isComplete() {
                    guard let channel = channels.findChannel(id: frame.channelId) else {
                        preconditionFailure(
                            "Received frame for non-existing channel \(frame.channelId)"
                        )
                    }
                    channel.dispatch(content: contentContext.contentFrames)
                    contentContext.reset()
                }
                continue
            }
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
            transportTask.cancel()  // drops the connection
            break  // stop processing any further frames
        }
    }

    init(
        inboundFrames: AsyncStream<any Frame>,
        channels: ChannelManager,
        transportTask: Task<Void, Never>,
        maxFrameSize: Int32 = 0  // no limit
    ) {
        self.inboundFrames = inboundFrames
        self.channels = channels
        self.transportTask = transportTask
        self.maxFrameSize = maxFrameSize
    }
}
