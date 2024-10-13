//
//  FrameCodableProtocol.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 13.10.2024.
//

import Foundation

protocol AMQPDecoder {
    func decode(_ type: Int8.Type) throws -> Int8
    func dncode(_ type: String.Type, isLong: Bool) throws -> String
    func dncode(_ type: Int16.Type) throws -> Int16
    func dncode(_ type: Int32.Type) throws -> Int32
    func dncode(_ type: Int64.Type) throws -> Int64
    func dncode(_ type: Bool.Type) throws -> Bool
    func dncode(_ type: Date.Type) throws -> Date
    func dncode(_ type: [String: AMQP.FieldValue].Type) throws -> [String: AMQP.FieldValue]
}

protocol AMQPDecodable {
    init(from decoder: AMQPDecoder) throws
}

protocol AMQPEncoder {
    func encode(_ value: Int8) throws
    func encode(_ value: String, isLong: Bool) throws
    func encode(_ value: Int16) throws
    func encode(_ value: Int32) throws
    func encode(_ value: Int64) throws
    func encode(_ value: Bool) throws
    func encode(_ value: Date) throws
    func encode(_ value: [String: AMQP.FieldValue]) throws
}

protocol AMQPEncodable {
    func encode(to encoder: AMQPEncoder) throws
}

protocol AMQPCodable: AMQPDecodable, AMQPEncodable {
}
