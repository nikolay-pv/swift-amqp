//
//  AMQPTransport.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//

import Foundation

protocol AMQPTransportProtocol {
    // TODO: figure the proper interface
    func connect() throws
    func close()
    func write(_ frame: AMQPFrame) throws
    func read() -> AMQPFrame
    var isConnected: Bool { get }
    var isDisconnected: Bool { get }
}

class FakeAMQPTransport: AMQPTransportProtocol {
    func connect() throws {}
    func close() {}
    func write(_ frame: AMQPFrame) throws {}
    func read() -> AMQPFrame { return .init(payload: Spec.Basic.Ack.init()) }
    var isConnected: Bool { return false }
    var isDisconnected: Bool { return true }
}
