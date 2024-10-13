//
//  AMQPFrame.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//

import Foundation

struct AMQPFrame {
    var type: Int8
    var channelId: Int16
    var payload: Data = .init()

    private static let prefixSize: Int = 8 // = sum(1 for type, 2 for channel, 4 for payload size, 1 for end char)
}
