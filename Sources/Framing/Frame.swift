import Foundation

protocol Frame: Sendable, FrameCodable {
    var type: UInt8 { get }
    var channelId: UInt16 { get }
    func asData() throws -> Data
}

extension Frame {
    /// serializes this object to be sent over the wire
    func asData() throws -> Data {
        let encoder = FrameEncoder()
        return try encoder.encode(self)
    }
}

internal func isContent(_ frame: Frame) -> Bool {
    frame is ContentHeaderFrame || frame is ContentBodyFrame
}

func decodeFrame(type: UInt8, from data: Data) throws -> Frame {
    // for errors see 4.2.3 General Frame Format
    if data.last != Spec.FrameEnd {
        throw FramingError.fatal("Frame doesn't end with the frame-end octet")
    }
    let decoder: FrameDecoder = .init()
    switch type {
    case Spec.FrameHeader:
        return try decoder.decode(ContentHeaderFrame.self, from: data)
    case Spec.FrameBody:
        return try decoder.decode(ContentBodyFrame.self, from: data)
    case Spec.FrameMethod:
        return try decoder.decode(MethodFrame.self, from: data)
    case Spec.FrameHeartbeat:
        return try decoder.decode(HeartbeatFrame.self, from: data)
    default:
        throw FramingError.fatal("Unknown frame type \(type) to decode")
    }
}

// 4.2.2 Protocol Header
struct ProtocolHeaderFrame {
    static let reservedType: UInt8 = .max
    var type: UInt8 { ProtocolHeaderFrame.reservedType }
    var channelId: UInt16 { 0 }

    static let protocolNameLength: UInt32 = 4
    var protocolName: [UInt8] = Array("AMQP".utf8)
    var majorVersion: UInt8
    var minorVersion: UInt8
    var revision: UInt8

    init(majorVersion: UInt8, minorVersion: UInt8, revision: UInt8) {
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
        self.revision = revision
    }

    static let specHeader = ProtocolHeaderFrame(
        majorVersion: Spec.ProtocolLevel.MAJOR,
        minorVersion: Spec.ProtocolLevel.MINOR,
        revision: Spec.ProtocolLevel.REVISION
    )
}

extension ProtocolHeaderFrame: Equatable {}

extension ProtocolHeaderFrame: Frame {
    func encode(to encoder: any FrameEncoderProtocol) throws {
        for byte in protocolName {
            try encoder.encode(byte)
        }
        try encoder.encode(UInt8(0))
        try encoder.encode(majorVersion)
        try encoder.encode(minorVersion)
        try encoder.encode(revision)
    }

    init(from decoder: any FrameDecoderProtocol) throws {
        protocolName = try (0..<Self.protocolNameLength)
            .reduce(into: [UInt8]()) { partialResult, _ in
                partialResult.append(try decoder.decode(UInt8.self))
            }
        _ = try decoder.decode(UInt8.self)
        majorVersion = try decoder.decode(UInt8.self)
        minorVersion = try decoder.decode(UInt8.self)
        revision = try decoder.decode(UInt8.self)
    }

    var bytesCount: UInt32 { 8 }
}

// 2.3.5.1 Method Frames
// 4.2.3 General Frame Format
struct MethodFrame {
    var type: UInt8 { Spec.FrameMethod }
    var channelId: UInt16
    var payload: any FrameCodable
}

extension MethodFrame: Frame {
    init(from decoder: any FrameDecoderProtocol) throws {
        let wireType = try decoder.decode(UInt8.self)
        precondition(wireType == Spec.FrameMethod)
        channelId = try decoder.decode(UInt16.self)
        let expectedSize = try decoder.decode(UInt32.self)
        let classId = try decoder.decode(UInt16.self)
        let methodId = try decoder.decode(UInt16.self)
        let factory = try Spec.makeFactory(with: classId, and: methodId)
        payload = try factory(decoder)

        precondition(payload.bytesCount + 4 == expectedSize)
        let end = try decoder.decode(UInt8.self)
        precondition(end == Spec.FrameEnd)
    }

    func encode(to encoder: any FrameEncoderProtocol) throws {
        try encoder.encode(type)
        try encoder.encode(channelId)
        let method = payload as! any AMQPMethodProtocol
        // accounting for class and method IDs
        try encoder.encode(payload.bytesCount + 2 + 2)
        try encoder.encode(method.amqpClassId)
        try encoder.encode(method.amqpMethodId)
        try payload.encode(to: encoder)
        try encoder.encode(Spec.FrameEnd)
    }

    var bytesCount: UInt32 { 1 + 2 + 4 + 2 + 2 + payload.bytesCount + 1 }
}

// 4.2.3 General Frame Format
// 4.2.7 Heartbeat Frames
// Also https://www.rabbitmq.com/amqp-0-9-1-errata#section_12
struct HeartbeatFrame {
    var type: UInt8 { Spec.FrameHeartbeat }
    var channelId: UInt16 { 0 }
}

extension HeartbeatFrame: Equatable {}

extension HeartbeatFrame: Frame {
    init(from decoder: any FrameDecoderProtocol) throws {
        let wireType = try decoder.decode(UInt8.self)
        precondition(wireType == Spec.FrameHeartbeat)
        let wireChannelId = try decoder.decode(UInt16.self)
        if wireChannelId != 0 {
            throw Spec.HardError.frameError
        }
        let expectedSize = try decoder.decode(UInt32.self)
        precondition(expectedSize == 0)
        let end = try decoder.decode(UInt8.self)
        precondition(end == Spec.FrameEnd)
    }

    func encode(to encoder: any FrameEncoderProtocol) throws {
        try encoder.encode(type)
        try encoder.encode(channelId)
        try encoder.encode(UInt32(0))
        try encoder.encode(Spec.FrameEnd)
    }

    var bytesCount: UInt32 { 1 + 2 + 4 + 1 }
}

// 4.2.3 General Frame Format
// 2.3.5.2 Content Frames
struct ContentHeaderFrame {
    var type: UInt8 { Spec.FrameHeader }
    var channelId: UInt16
    var classId: UInt16
    var weight: UInt16 { 0 }
    var bodySize: UInt64
    var properties: Spec.BasicProperties
}

extension ContentHeaderFrame: Equatable {}

extension ContentHeaderFrame: Frame {
    init(from decoder: any FrameDecoderProtocol) throws {
        let wireType = try decoder.decode(UInt8.self)
        precondition(wireType == Spec.FrameHeader)
        channelId = try decoder.decode(UInt16.self)
        if channelId == 0 {
            throw Spec.HardError.channelError
        }
        _ = try decoder.decode(UInt32.self)
        classId = try decoder.decode(UInt16.self)
        let wireWeight = try decoder.decode(UInt16.self)
        // as per specs in 4.2.6.1
        precondition(wireWeight == 0)
        bodySize = try decoder.decode(UInt64.self)
        properties = try .init(from: decoder)
        let end = try decoder.decode(UInt8.self)
        precondition(end == Spec.FrameEnd)
    }

    func encode(to encoder: any FrameEncoderProtocol) throws {
        try encoder.encode(type)
        try encoder.encode(channelId)
        // 8 for bodySize, 2 and 2 for classId and weight
        try encoder.encode(UInt32(8 + 2 + 2 + properties.bytesCount))
        try encoder.encode(classId)
        try encoder.encode(weight)
        try encoder.encode(bodySize)
        try properties.encode(to: encoder)
        try encoder.encode(Spec.FrameEnd)
    }

    var bytesCount: UInt32 { 1 + 2 + 4 + 2 + 2 + 8 + properties.bytesCount + 1 }
}

// 2.3.5.2 Content Frames
struct ContentBodyFrame {
    var type: UInt8 { Spec.FrameBody }
    var channelId: UInt16
    var fragment: [UInt8]  // max size is UInt32.max
}

extension ContentBodyFrame: Equatable {}

extension ContentBodyFrame: Frame {
    // don't decode type the same was as classId and methodId in Methods are not decoded
    init(from decoder: any FrameDecoderProtocol) throws {
        let wireType = try decoder.decode(UInt8.self)
        precondition(wireType == Spec.FrameBody)
        channelId = try decoder.decode(UInt16.self)
        let expectedSize = try decoder.decode(UInt32.self)
        var wireFragment = [UInt8]()
        wireFragment.reserveCapacity(Int(expectedSize))
        for _ in 0..<expectedSize {
            wireFragment.append(try decoder.decode(UInt8.self))
        }
        fragment = consume wireFragment
        let end = try decoder.decode(UInt8.self)
        precondition(end == Spec.FrameEnd)
    }

    // don't encode type the same way as classId and methodId in Methods are not encoded
    func encode(to encoder: any FrameEncoderProtocol) throws {
        try encoder.encode(type)
        try encoder.encode(channelId)
        try encoder.encode(UInt32(fragment.count))
        try fragment.forEach { try encoder.encode($0) }
        try encoder.encode(Spec.FrameEnd)
    }

    var bytesCount: UInt32 { 1 + 2 + 4 + UInt32(fragment.count) + 1 }
}
