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
            freed.insert(id, at: freed.firstIndex(where: { $0 >= id }) ?? freed.endIndex)
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
        if nextFree > maxID {
            throw ConnectionError.maxChannelsLimitReached
        }
        let id = nextFree
        nextFree += 1
        return id
    }

    init(maxID: IDType) {
        // ensure > will work without overflow by sacrificing the last ID
        self.maxID = maxID == .max ? .max - 1 : maxID
    }
}

// in charge of bookkeeping the channels, allows making them and finding
// them by id, as well as removing them
final class ChannelManager: Sendable {
    // channel IDs are assigned starting from 1; channel-id 0 is reserved for
    // connection-level methods and is handled by `Connection` directly.

    struct ChannelHandle {
        // manager shouldn't increase the ref count of Channels, but only keep them in books (channel will call to be removed)
        unowned var channel: Channel
    }

    fileprivate struct ChannelsAndIDs {
        var channels: [UInt16: ChannelHandle] = [:]
        var channelIDs: ChannelIDs

        init(maxID: UInt16) {
            self.channelIDs = .init(maxID: maxID)
        }
    }

    private let channelsAndIds: NIOLockedValueBox<ChannelsAndIDs>

    // throws ConnectionError.maxChannelsLimitReached if no more channels can be
    // created (within agreed limits)
    func makeChannel(connection: Connection, maxFrameSize: Int32, logger: Logger) throws -> Channel {
        let channel: Channel = try channelsAndIds.withLockedValue {
            let id = try $0.channelIDs.next()
            let channel = Channel.init(
                connection: connection,
                id: id,
                logger: logger,
                maxFrameSize: maxFrameSize,
                manager: self
            )
            $0.channels[id] = ChannelHandle(channel: channel)
            return channel
        }
        return channel
    }

    func removeChannel(id: UInt16) {
        channelsAndIds.withLockedValue {
            if $0.channels.removeValue(forKey: id) != nil {
                $0.channelIDs.remove(id: id)
            }
        }
    }

    func findChannel(id: UInt16) -> Channel? {
        return channelsAndIds.withLockedValue {
            return $0.channels[id]?.channel
        }
    }

    func forEach(_ body: (Channel) -> Void) {
        // ensure channels are owned here, so there is no deadlock
        // it is possible that closure will hold the last instance of a channel,
        // that one will call `removeChannel` which will try to acquire a lock
        // again
        let channels = channelsAndIds.withLockedValue {
            var channels = [Channel]()
            for (_, ch) in $0.channels {
                let channel = ch.channel
                channels.append(channel)
            }
            return channels
        }
        for channel in channels {
            body(channel)
        }
    }

    // MARK: - init

    init(maxChannels: UInt16 = .max) {
        self.channelsAndIds = .init(.init(maxID: maxChannels))
    }
}
