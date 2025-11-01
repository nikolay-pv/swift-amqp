import Collections
import Logging
import NIOConcurrencyHelpers

private struct ChannelIDs {
    typealias IDType = UInt16
    private(set) var maxID: IDType
    private(set) var nextFree: IDType = 1
    private(set) var occupied: OrderedSet<IDType> = []
    private(set) var freed: OrderedSet<IDType> = []

    func isFree(_ id: IDType) -> Bool { !occupied.contains(id) && nextFree <= id }

    mutating func remove(id: IDType) {
        if id == nextFree - 1 {
            nextFree -= 1
        } else {
            freed.insert(id, at: occupied.firstIndex(where: { $0 >= id }) ?? occupied.endIndex)
        }
        occupied.remove(id)
    }

    // throws ConnectionError.maxChannelsLimitReached if no more ids are
    // available
    mutating func next() throws -> IDType {
        if !freed.isEmpty {
            let id = freed.removeFirst()
            return id
        }
        if nextFree == maxID {
            throw ConnectionError.maxChannelsLimitReached
        }
        let id = nextFree
        nextFree += 1
        return id
    }
}

// in charge of bookkeeping the channels, allows making them and finding
// them by id, as well as removing them
final class ChannelManager: @unchecked Sendable {
    // channel0 is special and is used for communications before any channel exists
    // it never explicitly created on the server side (so no requestOpen call is made for it)
    let channel0: Channel

    private let channelsLock = NIOLock()
    private var channels: [UInt16: Channel] = [:]
    private var channelIDs: ChannelIDs

    // throws ConnectionError.maxChannelsLimitReached if no more channels can be
    // created (within agreed limits)
    func makeChannel(transport: TransportProtocol, logger: Logger) throws -> Channel {
        let channel: Channel = try channelsLock.withLock {
            let id = try channelIDs.next()
            let channel = Channel.init(transport: transport, id: id, logger: logger)
            channels[id] = channel
            return channel
        }
        return channel
    }

    func removeChannel(id: UInt16) {
        channelsLock.withLock {
            if channels.removeValue(forKey: id) != nil {
                channelIDs.remove(id: id)
            }
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

    func forEach(_ body: (Channel) -> Void) {
        channelsLock.withLock {
            for channel in channels.values {
                body(channel)
            }
        }
    }

    // MARK: - init

    // initializes the channel0 with given transport and the logger
    init(transport: TransportProtocol, logger: Logger, maxChannels: UInt16 = .max) {
        self.channel0 = .init(transport: transport, id: 0, logger: logger)
        self.channelIDs = .init(maxID: maxChannels)
    }
}
