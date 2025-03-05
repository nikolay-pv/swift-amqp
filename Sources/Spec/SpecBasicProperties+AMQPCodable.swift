//   NOTE: This -*- swift -*- source code is implemented manually
//

import Foundation  // for Date

extension Spec.BasicProperties: AMQPCodable {

    enum PropertyFlags: UInt16 {
        case ContentType = 0b10000000_00000000
        case ContentEncoding = 0b1000000_00000000
        case Headers = 0b100000_00000000
        case DeliveryMode = 0b10000_00000000
        case Priority = 0b1000_00000000
        case CorrelationId = 0b100_00000000
        case ReplyTo = 0b10_00000000
        case Expiration = 0b100000000
        case MessageId = 0b10000000
        case Timestamp = 0b1000000
        case TypeFlag = 0b100000
        case UserId = 0b10000
        case AppId = 0b1000
        case ClusterId = 0b100

        func contained(_ flags: UInt16) -> Bool {
            (flags & self.rawValue) != 0
        }
    }

    func encode(to encoder: AMQPEncoder) throws {
        var flags: UInt16 = 0
        var encodeCalls: [() throws -> Void] = .init()
        if let contentType {
            flags |= PropertyFlags.ContentType.rawValue
            encodeCalls.append({ try encoder.encode(contentType, isLong: false) })
        }
        if let contentEncoding {
            flags |= PropertyFlags.ContentEncoding.rawValue
            encodeCalls.append({ try encoder.encode(contentEncoding, isLong: false) })
        }
        if let headers {
            flags |= PropertyFlags.Headers.rawValue
            encodeCalls.append({ try encoder.encode(headers) })
        }
        if let deliveryMode {
            flags |= PropertyFlags.DeliveryMode.rawValue
            encodeCalls.append({ try encoder.encode(deliveryMode) })
        }
        if let priority {
            flags |= PropertyFlags.Priority.rawValue
            encodeCalls.append({ try encoder.encode(priority) })
        }
        if let correlationId {
            flags |= PropertyFlags.CorrelationId.rawValue
            encodeCalls.append({ try encoder.encode(correlationId, isLong: false) })
        }
        if let replyTo {
            flags |= PropertyFlags.ReplyTo.rawValue
            encodeCalls.append({ try encoder.encode(replyTo, isLong: false) })
        }
        if let expiration {
            flags |= PropertyFlags.Expiration.rawValue
            encodeCalls.append({ try encoder.encode(expiration, isLong: false) })
        }
        if let messageId {
            flags |= PropertyFlags.MessageId.rawValue
            encodeCalls.append({ try encoder.encode(messageId, isLong: false) })
        }
        if let timestamp {
            flags |= PropertyFlags.Timestamp.rawValue
            encodeCalls.append({ try encoder.encode(timestamp) })
        }
        if let type {
            flags |= PropertyFlags.TypeFlag.rawValue
            encodeCalls.append({ try encoder.encode(type, isLong: false) })
        }
        if let userId {
            flags |= PropertyFlags.UserId.rawValue
            encodeCalls.append({ try encoder.encode(userId, isLong: false) })
        }
        if let appId {
            flags |= PropertyFlags.AppId.rawValue
            encodeCalls.append({ try encoder.encode(appId, isLong: false) })
        }
        if let clusterId {
            flags |= PropertyFlags.ClusterId.rawValue
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

    init(from decoder: AMQPDecoder) throws {
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
        var timestamp: Date?
        var type: String?
        var userId: String?
        var appId: String?
        var clusterId: String?

        if PropertyFlags.ContentType.contained(flags) {
            contentType = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.ContentEncoding.contained(flags) {
            contentEncoding = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.Headers.contained(flags) {
            headers = try decoder.decode(Spec.Table.self)
        }
        if PropertyFlags.DeliveryMode.contained(flags) {
            deliveryMode = try decoder.decode(Int8.self)
        }
        if PropertyFlags.Priority.contained(flags) {
            priority = try decoder.decode(Int8.self)
        }
        if PropertyFlags.CorrelationId.contained(flags) {
            correlationId = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.ReplyTo.contained(flags) {
            replyTo = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.Expiration.contained(flags) {
            expiration = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.MessageId.contained(flags) {
            messageId = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.Timestamp.contained(flags) {
            timestamp = try decoder.decode(Date.self)
        }
        if PropertyFlags.TypeFlag.contained(flags) {
            type = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.UserId.contained(flags) {
            userId = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.AppId.contained(flags) {
            appId = try decoder.decode(String.self, isLong: false)
        }
        if PropertyFlags.ClusterId.contained(flags) {
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
            flags |= PropertyFlags.ContentType.rawValue
            size += UInt32(contentType.shortBytesCount)
        }
        if let contentEncoding {
            flags |= PropertyFlags.ContentEncoding.rawValue
            size += UInt32(contentEncoding.shortBytesCount)
        }
        if let headers {
            flags |= PropertyFlags.Headers.rawValue
            size += headers.bytesCount
        }
        if let deliveryMode {
            flags |= PropertyFlags.DeliveryMode.rawValue
            size += 1
        }
        if let priority {
            flags |= PropertyFlags.Priority.rawValue
            size += 1
        }
        if let correlationId {
            flags |= PropertyFlags.CorrelationId.rawValue
            size += UInt32(correlationId.shortBytesCount)
        }
        if let replyTo {
            flags |= PropertyFlags.ReplyTo.rawValue
            size += UInt32(replyTo.shortBytesCount)
        }
        if let expiration {
            flags |= PropertyFlags.Expiration.rawValue
            size += UInt32(expiration.shortBytesCount)
        }
        if let messageId {
            flags |= PropertyFlags.MessageId.rawValue
            size += UInt32(messageId.shortBytesCount)
        }
        if let timestamp {
            flags |= PropertyFlags.Timestamp.rawValue
            size += UInt32(timestamp.bytesCount)
        }
        if let type {
            flags |= PropertyFlags.TypeFlag.rawValue
            size += UInt32(type.shortBytesCount)
        }
        if let userId {
            flags |= PropertyFlags.UserId.rawValue
            size += UInt32(userId.shortBytesCount)
        }
        if let appId {
            flags |= PropertyFlags.AppId.rawValue
            size += UInt32(appId.shortBytesCount)
        }
        if let clusterId {
            flags |= PropertyFlags.ClusterId.rawValue
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
