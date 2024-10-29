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
    let frame_end: UInt8 = UInt8(AMQP.FrameEnd)
}

extension AMQPFrame: AMQPCodable {
    init(from decoder: any AMQPDecoder) throws {
        type = try decoder.decode(UInt8.self)
        channelId = try decoder.decode(UInt16.self)
        let expectedSize = try decoder.decode(UInt32.self)
        switch type {
        case AMQP.FrameMethod:
            let classId = try decoder.decode(UInt16.self)
            let methodId = try decoder.decode(UInt16.self)
            let factory = try AMQP.makeFactory(with: classId, and: methodId)
            payload = try factory(decoder)
        case AMQP.FrameHeader: fallthrough
        case AMQP.FrameBody: fallthrough
        case AMQP.FrameHeartbeat:
            fatalError("Not implemented yet")
        default: throw AMQPError.DecodingError.unknownFrameType(type)
        }
        precondition(payload.bytesCount == expectedSize)
    }

    func encode(to encoder: any AMQPEncoder) throws {
        try encoder.encode(type)
        try encoder.encode(channelId)
        try encoder.encode(size)
        try payload.encode(to: encoder)
        try encoder.encode(frame_end)
    }

    var bytesCount: UInt32 {
        7 + 1 + size
    }
}
