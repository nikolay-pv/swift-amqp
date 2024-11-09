//
//  AMQPFrame.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//

import Foundation

struct AMQPFrame {
    var type: UInt8
    var channelId: UInt16 = 0
    var size: UInt32 { payload.bytesCount }
    var payload: any AMQPCodable
    let frameEnd: UInt8 = UInt8(Spec.FrameEnd)
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
            fatalError("Not implemented yet")
        default: throw AMQPError.DecodingError.unknownFrameType(type)
        }
        precondition(payload.bytesCount == expectedSize)
        let end = try decoder.decode(UInt8.self)
        precondition(end == frameEnd)
    }

    func encode(to encoder: any AMQPEncoder) throws {
        try encoder.encode(type)
        try encoder.encode(channelId)
        try encoder.encode(size)
        try payload.encode(to: encoder)
        try encoder.encode(frameEnd)
    }

    var bytesCount: UInt32 { 7 + 1 + size }
}
