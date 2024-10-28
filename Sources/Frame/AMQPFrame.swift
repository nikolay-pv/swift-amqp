//
//  AMQPFrame.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//

import Foundation

struct AMQPFrame {
    enum FrameType: Int8 {
        case method = 1
        case header = 2
        case body = 3
        case heartbeat = 4
    }
    var type: FrameType
    var channelId: UInt16 = 0
    var size: UInt32 { payload.bytesCount }
    var payload: any AMQPObjectProtocol & AMQPCodable
    let frame_end: UInt8 = 0

    private static let prefixSize: Int = 7 // = sum(1 for type, 2 for channel, 4 for payload size, 1 for end char)
}
