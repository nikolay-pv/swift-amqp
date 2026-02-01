import AsyncAlgorithms

final class FramesRouter: Sendable {
    private let inboundFrames: AsyncStream<any Frame>
    private let channels: ChannelManager
    private let transportTask: Task<Void, Never>

    func execute() async {
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
            transportTask.cancel()  // drops the connection
            break  // stop processing any further frames
        }
    }

    init(
        inboundFrames: AsyncStream<any Frame>,
        channels: ChannelManager,
        transportTask: Task<Void, Never>,
    ) {
        self.inboundFrames = inboundFrames
        self.channels = channels
        self.transportTask = transportTask
    }
}
