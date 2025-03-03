//
//  AMQPFrame.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//

import Foundation

// 4.2.2 AMQP
struct AMQPProtocolHeader {
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

    static let specHeader = AMQPProtocolHeader(
        majorVersion: Spec.ProtocolLevel.MAJOR,
        minorVersion: Spec.ProtocolLevel.MINOR,
        revision: Spec.ProtocolLevel.REVISION
    )
}

extension AMQPProtocolHeader: AMQPCodable {
    func encode(to encoder: any AMQPEncoder) throws {
        for byte in protocolName {
            try encoder.encode(byte)
        }
        try encoder.encode(UInt8(0))
        try encoder.encode(majorVersion)
        try encoder.encode(minorVersion)
        try encoder.encode(revision)
    }

    init(from decoder: any AMQPDecoder) throws {
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

struct AMQPFrame: Sendable {
    var type: UInt8 = Kind.method
    var channelId: UInt16 = 0
    var size: UInt32 { payload.bytesCount }
    var payload: any AMQPCodable
    let frameEnd: UInt8 = UInt8(Spec.FrameEnd)

    enum Kind {
        static let method = Spec.FrameMethod
        static let header = Spec.FrameHeader
        static let heartbeat = Spec.FrameHeartbeat
        static let body = Spec.FrameBody
    }
}

extension AMQPFrame: AMQPCodable {
    init(from decoder: any AMQPDecoder) throws {
        type = try decoder.decode(UInt8.self)
        channelId = try decoder.decode(UInt16.self)
        let expectedSize = try decoder.decode(UInt32.self)
        switch type {
        case Spec.FrameMethod:
            let classId = try decoder.decode(UInt16.self)
            let methodId = try decoder.decode(UInt16.self)
            let factory = try Spec.makeFactory(with: classId, and: methodId)
            payload = try factory(decoder)
        case Spec.FrameHeader, Spec.FrameBody, Spec.FrameHeartbeat:
            // TODO implement these
            fatalError("Not implemented yet")
        default: throw AMQPError.CodingError.unknownFrameType(type)
        }
        precondition(payload.bytesCount + 4 == expectedSize)
        let end = try decoder.decode(UInt8.self)
        precondition(end == frameEnd)
    }

    func encode(to encoder: any AMQPEncoder) throws {
        switch type {
        case Spec.FrameMethod:
            try encoder.encode(type)
            try encoder.encode(channelId)
            let method = payload as! any AMQPMethodProtocol
            // TODO: that's a hack, I couldn't implement the symmetrical decode encode because I need the class and method ids to decide which object to create
            try encoder.encode(payload.bytesCount + 2 + 2)
            try encoder.encode(method.amqpClassId)
            try encoder.encode(method.amqpMethodId)
            try payload.encode(to: encoder)
            try encoder.encode(frameEnd)
        case Spec.FrameHeader, Spec.FrameBody, Spec.FrameHeartbeat:
            // TODO implement these
            fatalError("Not implemented yet")
        default: throw AMQPError.CodingError.unknownFrameType(type)
        }
    }

    var bytesCount: UInt32 {
        switch type {
        case Spec.FrameMethod: return 7 + 1 + size
        case Spec.FrameHeader, Spec.FrameBody, Spec.FrameHeartbeat:
            // TODO implement these
            fatalError("Not implemented yet")
        default:
            fatalError("Reached an unreachable code")
        }
    }
}
