//   NOTE: This -*- swift -*- source code is implemented manually
//

extension Spec.BasicProperties: FrameCodable {

    enum PropertyFlags: UInt16 {
        case contentType = 0b10000000_00000000
        case contentEncoding = 0b1000000_00000000
        case headers = 0b100000_00000000
        case deliveryMode = 0b10000_00000000
        case priority = 0b1000_00000000
        case correlationId = 0b100_00000000
        case replyTo = 0b10_00000000
        case expiration = 0b100000000
        case messageId = 0b10000000
        case timestamp = 0b1000000
        case typeFlag = 0b100000
        case userId = 0b10000
        case appId = 0b1000
        case clusterId = 0b100

        func contained(_ flags: UInt16) -> Bool {
            (flags & self.rawValue) != 0
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func encode(to encoder: FrameEncoderProtocol) throws {
        var flags: UInt16 = 0
        var encodeCalls: [() throws -> Void] = .init()
        if let contentType {
            flags |= PropertyFlags.contentType.rawValue
            encodeCalls.append({ try encoder.encode(contentType, isLong: false) })
        }
        if let contentEncoding {
            flags |= PropertyFlags.contentEncoding.rawValue
            encodeCalls.append({ try encoder.encode(contentEncoding, isLong: false) })
        }
        if let headers {
            flags |= PropertyFlags.headers.rawValue
            encodeCalls.append({ try encoder.encode(headers) })
        }
        if let deliveryMode {
            flags |= PropertyFlags.deliveryMode.rawValue
            encodeCalls.append({ try encoder.encode(deliveryMode) })
        }
        if let priority {
            flags |= PropertyFlags.priority.rawValue
            encodeCalls.append({ try encoder.encode(priority) })
        }
        if let correlationId {
            flags |= PropertyFlags.correlationId.rawValue
            encodeCalls.append({ try encoder.encode(correlationId, isLong: false) })
        }
        if let replyTo {
            flags |= PropertyFlags.replyTo.rawValue
            encodeCalls.append({ try encoder.encode(replyTo, isLong: false) })
        }
        if let expiration {
            flags |= PropertyFlags.expiration.rawValue
            encodeCalls.append({ try encoder.encode(expiration, isLong: false) })
        }
        if let messageId {
            flags |= PropertyFlags.messageId.rawValue
            encodeCalls.append({ try encoder.encode(messageId, isLong: false) })
        }
        if let timestamp {
            flags |= PropertyFlags.timestamp.rawValue
            encodeCalls.append({ try encoder.encode(timestamp) })
        }
        if let type {
            flags |= PropertyFlags.typeFlag.rawValue
            encodeCalls.append({ try encoder.encode(type, isLong: false) })
        }
        if let userId {
            flags |= PropertyFlags.userId.rawValue
            encodeCalls.append({ try encoder.encode(userId, isLong: false) })
        }
        if let appId {
            flags |= PropertyFlags.appId.rawValue
            encodeCalls.append({ try encoder.encode(appId, isLong: false) })
        }
        if let clusterId {
            flags |= PropertyFlags.clusterId.rawValue
            encodeCalls.append({ try encoder.encode(clusterId, isLong: false) })
        }
        // the following works for flags == 0
        while true {
            let remainder = flags >> 16
            var flagsChunk: UInt16 = flags & 0xFFFF
            if remainder != 0 {
                // indicates that another set of flags will follow
                // 4.2.6.1 The Content Header
                flagsChunk |= 1
            }
            try encoder.encode(flagsChunk)
            flags = remainder
            if flags == 0 {
                break
            }
        }
        try encodeCalls.forEach { try $0() }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(from decoder: FrameDecoderProtocol) throws {
        var flags: UInt16 = 0
        var chunkCount = 0
        while true {
            let flagsChunk = try decoder.decode(UInt16.self)
            flags |= (flagsChunk << (chunkCount * 16))
            // no bit is set to read the following chunk?
            if (flagsChunk & 1) == 0 {
                break
            }
            chunkCount += 1
        }
        var contentType: String?
        var contentEncoding: String?
        var headers: [String: Spec.FieldValue]?
        var deliveryMode: Int8?
        var priority: Int8?
        var correlationId: String?
        var replyTo: String?
        var expiration: String?
        var messageId: String?
        var timestamp: Timestamp?
        var type: String?
        var userId: String?
        var appId: String?
        var clusterId: String?

        if PropertyFlags.contentType.contained(flags) {
            contentType = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.contentEncoding.contained(flags) {
            contentEncoding = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.headers.contained(flags) {
            headers = try decoder.decode(Spec.Table.self)
        }
        if PropertyFlags.deliveryMode.contained(flags) {
            deliveryMode = try decoder.decode(Int8.self)
        }
        if PropertyFlags.priority.contained(flags) {
            priority = try decoder.decode(Int8.self)
        }
        if PropertyFlags.correlationId.contained(flags) {
            correlationId = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.replyTo.contained(flags) {
            replyTo = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.expiration.contained(flags) {
            expiration = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.messageId.contained(flags) {
            messageId = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.timestamp.contained(flags) {
            timestamp = try decoder.decode(Timestamp.self)
        }
        if PropertyFlags.typeFlag.contained(flags) {
            type = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.userId.contained(flags) {
            userId = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.appId.contained(flags) {
            appId = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.clusterId.contained(flags) {
            clusterId = try decoder.decode(String.self, isLong: false)
        }
        self.init(
            contentType: contentType,
            contentEncoding: contentEncoding,
            headers: headers,
            deliveryMode: deliveryMode,
            priority: priority,
            correlationId: correlationId,
            replyTo: replyTo,
            expiration: expiration,
            messageId: messageId,
            timestamp: timestamp,
            type: type,
            userId: userId,
            appId: appId,
            clusterId: clusterId
        )
    }

    var bytesCount: UInt32 {
        var flags: UInt16 = 0
        var size: UInt32 = 0
        if let contentType {
            flags |= PropertyFlags.contentType.rawValue
            size += UInt32(contentType.shortBytesCount)
        }
        if let contentEncoding {
            flags |= PropertyFlags.contentEncoding.rawValue
            size += UInt32(contentEncoding.shortBytesCount)
        }
        if let headers {
            flags |= PropertyFlags.headers.rawValue
            size += headers.bytesCount
        }
        if deliveryMode != nil {
            flags |= PropertyFlags.deliveryMode.rawValue
            size += 1
        }
        if priority != nil {
            flags |= PropertyFlags.priority.rawValue
            size += 1
        }
        if let correlationId {
            flags |= PropertyFlags.correlationId.rawValue
            size += UInt32(correlationId.shortBytesCount)
        }
        if let replyTo {
            flags |= PropertyFlags.replyTo.rawValue
            size += UInt32(replyTo.shortBytesCount)
        }
        if let expiration {
            flags |= PropertyFlags.expiration.rawValue
            size += UInt32(expiration.shortBytesCount)
        }
        if let messageId {
            flags |= PropertyFlags.messageId.rawValue
            size += UInt32(messageId.shortBytesCount)
        }
        if let timestamp {
            flags |= PropertyFlags.timestamp.rawValue
            size += UInt32(timestamp.bytesCount)
        }
        if let type {
            flags |= PropertyFlags.typeFlag.rawValue
            size += UInt32(type.shortBytesCount)
        }
        if let userId {
            flags |= PropertyFlags.userId.rawValue
            size += UInt32(userId.shortBytesCount)
        }
        if let appId {
            flags |= PropertyFlags.appId.rawValue
            size += UInt32(appId.shortBytesCount)
        }
        if let clusterId {
            flags |= PropertyFlags.clusterId.rawValue
            size += UInt32(clusterId.shortBytesCount)
        }
        // the following works for flags == 0
        while true {
            let remainder = flags >> 16
            var flagsChunk: UInt16 = flags & 0xFFFF
            if remainder != 0 {
                // indicates that another set of flags will follow
                // 4.2.6.1 The Content Header
                flagsChunk |= 1
            }
            size += 2
            flags = remainder
            if flags == 0 {
                break
            }
        }
        return size
    }
}
