//
//  FrameCodableProtocol.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 13.10.2024.
//

import Foundation

protocol AMQPDecoder {
    func decode(_ type: Bool.Type) throws -> Bool
    func decode(_ type: Int8.Type) throws -> Int8
    func decode(_ type: Int16.Type) throws -> Int16
    func decode(_ type: Int32.Type) throws -> Int32
    func decode(_ type: Int64.Type) throws -> Int64
    func decode(_ type: UInt8.Type) throws -> UInt8
    func decode(_ type: UInt16.Type) throws -> UInt16
    func decode(_ type: UInt32.Type) throws -> UInt32
    func decode(_ type: UInt64.Type) throws -> UInt64
    func decode(_ type: Float.Type) throws -> Float
    func decode(_ type: Double.Type) throws -> Double
    func decode(_ type: Date.Type) throws -> Date
    func decode(_ type: String.Type, isLong: Bool) throws -> String
    func decode(_ type: [String: AMQP.FieldValue].Type) throws -> [String: AMQP.FieldValue]
}

protocol AMQPDecodable {
    init(from decoder: AMQPDecoder) throws
}

protocol AMQPEncoder {
    func encode(_ value: Bool) throws
    func encode(_ value: Int8) throws
    func encode(_ value: Int16) throws
    func encode(_ value: Int32) throws
    func encode(_ value: Int64) throws
    func encode(_ value: UInt8) throws
    func encode(_ value: UInt16) throws
    func encode(_ value: UInt32) throws
    func encode(_ value: UInt64) throws
    func encode(_ value: Float) throws
    func encode(_ value: Double) throws
    func encode(_ value: Date) throws
    func encode(_ value: String, isLong: Bool) throws
    func encode(_ value: [String: AMQP.FieldValue]) throws
}

protocol AMQPEncodable {
    func encode(to encoder: AMQPEncoder) throws
    var bytesCount: UInt32 { get }
}

protocol AMQPCodable: AMQPDecodable, AMQPEncodable {
}
