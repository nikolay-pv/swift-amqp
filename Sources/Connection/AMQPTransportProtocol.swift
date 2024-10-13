//
//  AMQPTransport.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.09.2024.
//


protocol AMQPTransportProtocol {
    func connect() throws
    func close()
    // TODO: make it Data
    func write(_ data: String) throws
    // TODO: figure the proper interface
    func readFrame() -> String
    var isConnected: Bool { get }
    var isDisconnected: Bool { get }
}

class FakeAMQPTransport: AMQPTransportProtocol {
    func connect() throws {
    }
    func close() {
    }
    func write(_ data: String) throws {
    }
    func readFrame() -> String {
        return ""
    }
    var isConnected: Bool {
        return false
    }
    var isDisconnected: Bool {
        return true
    }
}
