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
    func write(_ frame: MethodFrame) throws
    func read() -> MethodFrame
    var isConnected: Bool { get }
    var isDisconnected: Bool { get }
}

class FakeAMQPTransport: AMQPTransportProtocol {
    func connect() throws {}
    func close() {}
    func write(_ frame: MethodFrame) throws {}
    func read() -> MethodFrame { return .init(payload: Spec.Basic.Ack.init()) }
    var isConnected: Bool { return false }
    var isDisconnected: Bool { return true }
}
