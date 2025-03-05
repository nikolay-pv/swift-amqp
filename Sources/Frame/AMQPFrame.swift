//
//  AMQPFrame.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//

import Foundation

protocol Frame: Sendable, AMQPCodable {
    var type: UInt8 { get }
    var channelId: UInt16 { get }
}

// 4.2.2 Protocol Header
struct ProtocolHeaderFrame {
    let type: UInt8 = .max
    let channelId: UInt16 = 0

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

extension ProtocolHeaderFrame: Frame {
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

// 2.3.5.1 Method Frames
// 4.2.3 General Frame Format
struct MethodFrame {
    var type: UInt8 = Spec.FrameMethod
    var channelId: UInt16 = 0
    var payload: any AMQPCodable
    let frameEnd: UInt8 = UInt8(Spec.FrameEnd)
}

extension MethodFrame: Frame {
    init(from decoder: any AMQPDecoder) throws {
        type = try decoder.decode(UInt8.self)
        precondition(type == Spec.FrameMethod)

        channelId = try decoder.decode(UInt16.self)
        let expectedSize = try decoder.decode(UInt32.self)
        let classId = try decoder.decode(UInt16.self)
        let methodId = try decoder.decode(UInt16.self)
        let factory = try Spec.makeFactory(with: classId, and: methodId)
        payload = try factory(decoder)

        precondition(payload.bytesCount + 4 == expectedSize)
        let end = try decoder.decode(UInt8.self)
        precondition(end == frameEnd)
    }

    func encode(to encoder: any AMQPEncoder) throws {
        try encoder.encode(type)
        try encoder.encode(channelId)
        let method = payload as! any AMQPMethodProtocol
        // accounting for class and method IDs
        try encoder.encode(payload.bytesCount + 2 + 2)
        try encoder.encode(method.amqpClassId)
        try encoder.encode(method.amqpMethodId)
        try payload.encode(to: encoder)
        try encoder.encode(frameEnd)
    }

    var bytesCount: UInt32 { 1 + 2 + 2 + 2 + 1 + payload.bytesCount }
}

// 4.2.3 General Frame Format
// 4.2.7 Heartbeat Frames
struct HeartbeatFrame {
    let type: UInt8 = Spec.FrameHeartbeat
    let channelId: UInt16 = 0
    let frameEnd: UInt8 = UInt8(Spec.FrameEnd)
}

extension HeartbeatFrame {
    init(from decoder: any AMQPDecoder) throws {
        let wireType = try decoder.decode(UInt8.self)
        precondition(wireType == type)
        let wireChannelId = try decoder.decode(UInt16.self)
        precondition(wireChannelId == 0)
        let expectedSize = try decoder.decode(UInt32.self)
        precondition(expectedSize == 0)
        let end = try decoder.decode(UInt8.self)
        precondition(end == frameEnd)
    }

    func encode(to encoder: any AMQPEncoder) throws {
        try encoder.encode(type)
        try encoder.encode(channelId)
        try encoder.encode(UInt32(0))
        try encoder.encode(frameEnd)
    }

    var bytesCount: UInt32 { 1 + 2 + 4 + 1 }
}

// 4.2.3 General Frame Format
// 2.3.5.2 Content Frames
struct ContentHeaderFrame {
    let type: UInt8 = Spec.FrameHeader
    var channelId: UInt16 = 0
    var bodySize: UInt64
    var properties: Spec.BasicProperties
    let frameEnd: UInt8 = UInt8()
}

extension ContentHeaderFrame: Frame {
    init(from decoder: any AMQPDecoder) throws {
        let wireType = try decoder.decode(UInt8.self)
        precondition(wireType == type)
        channelId = try decoder.decode(UInt16.self)
        let expectedSize = try decoder.decode(UInt32.self)

        let classId = try decoder.decode(UInt16.self)
        precondition(classId == Spec.BasicProperties.amqpClassId)
        bodySize = try decoder.decode(UInt64.self)
        properties = try .init(from: decoder)
        let end = try decoder.decode(UInt8.self)
        precondition(end == frameEnd)
    }

    func encode(to encoder: any AMQPEncoder) throws {
        try encoder.encode(type)
        try encoder.encode(channelId)
        try encoder.encode(UInt32(2 + 8 + properties.bytesCount + 1))
        try encoder.encode(bodySize)
        try properties.encode(to: encoder)
        try encoder.encode(frameEnd)
    }

    var bytesCount: UInt32 { 1 + 2 + 8 + properties.bytesCount + 1 }
}

// 2.3.5.2 Content Frames
// TODO: implement this
// struct ContentBodyFrame {
//     var type: UInt8 = Spec.FrameBody
//     var channelId: UInt16 = 0
//     var payload: any AMQPCodable
//     let frameEnd: UInt8 = UInt8(Spec.FrameEnd)
// }
