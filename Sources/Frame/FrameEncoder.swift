//
//  AMQPEncoder.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 13.10.2024.
//

import Foundation

class FrameEncoder {
    func encode<T>(_ value: T) throws -> Data where T : AMQPEncodable {
        let encoder = _FrameEncoder()
        try value.encode(to: encoder)
        return encoder.complete()
    }
}

fileprivate extension Data {
    mutating func append(_ value: Int8) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    mutating func append(_ value: UInt8) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    mutating func append(_ value: Int16) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    mutating func append(_ value: UInt16) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    mutating func append(_ value: Int32) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    mutating func append(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    mutating func append(_ value: UInt64) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    mutating func append(_ value: Int64) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }
}

private extension AMQP.FieldValue {
    func encode(to data: inout Data) throws {
        data.append(self.type)
        self.asWrappedValue.encode(to: &data)
    }

    var asWrappedValue: _FrameEncoder.WrappedValue {
        return switch self {
        case .long(let value): .int32(value)
        case .decimal(let scale, let value): .decimal(scale, value)
        case .longstr(let value): .longstring(value)
        case .timestamp(let value): .timestamp(value)
        case .table(let value): .dictionary(value)
        case .void: .void(self.type)
        }
    }
}

private class _FrameEncoder : AMQPEncoder {
    enum WrappedValue: Equatable {
        case shortstring(String)
        case longstring(String)
        case uint8(UInt8)
        case int8(Int8)
        case uint16(UInt16)
        case int16(Int16)
        case uint32(UInt32)
        case int32(Int32)
        case uint64(UInt64)
        case int64(Int64)
        case float(Float)
        case double(Double)
        case bool(Bool)
        case timestamp(Date)
        case dictionary([String : AMQP.FieldValue])
        case void(UInt8) // only for field values
        case decimal(UInt8, Int32) // only for field values

        func encode(to data: inout Data) {
            switch self {
            case .shortstring(let value):
                withUnsafeBytes(of: value.shortSize.bigEndian) {
                    data.append(contentsOf: $0)
                }
                data.append(contentsOf: value.utf8)
            case .longstring(let value):
                withUnsafeBytes(of: value.count.bigEndian) {
                    data.append(contentsOf: $0)
                }
                data.append(contentsOf: value.utf8)
            case .uint8(let value):
                data.append(value.bigEndian)
            case .int8(let value):
                data.append(value.bigEndian)
            case .uint16(let value):
                data.append(value.bigEndian)
            case .int16(let value):
                data.append(value.bigEndian)
            case .uint32(let value):
                data.append(value.bigEndian)
            case .int32(let value):
                data.append(value.bigEndian)
            case .uint64(let value):
                data.append(value.bigEndian)
            case .int64(let value):
                data.append(value.bigEndian)
            case .bool(let value):
                data.append(Int8(value ? 1 : 0))
            case .float(let value):
                data.append(UInt32(value.bitPattern.bigEndian))
            case .double(let value):
                data.append(UInt64(value.bitPattern.bigEndian))
            case .timestamp(let value):
                let milliseconds = value.millisecondsSince1970
                data.append(milliseconds.bigEndian)
            case .dictionary(let table):
                precondition(table.count <= UInt16.max)
                data.append(UInt16(data.count))
                if !table.isEmpty {
                    for (key, value) in table {
                        withUnsafeBytes(of: key.shortSize.bigEndian) {
                            data.append(contentsOf: $0)
                        }
                        data.append(contentsOf: key.utf8)
                        value.asWrappedValue.encode(to: &data)
                    }
                }
            case .void(let value):
                data.append(value)
            case .decimal(let scale, let value):
                data.append(scale.bigEndian)
                data.append(value.bigEndian)
            }
        }

        init(_ value: String, isLong: Bool) {
            self = isLong ? .longstring(value) : .shortstring(value)
        }
        init(_ value: Int8) {
            self = .int8(value)
        }
        init (_ value: Int16) {
            self = .int16(value)
        }
        init (_ value: Int32) {
            self = .int32(value)
        }
        init (_ value: Int64) {
            self = .int64(value)
        }
        init (_ value: Bool) {
            self = .bool(value)
        }
        init (_ value: Date) {
            self = .timestamp(value)
        }
        init (_ value: [String : AMQP.FieldValue]) {
            self = .dictionary(value)
        }
    }
    var storage = [WrappedValue]()

    func complete() -> Data {
        var data = Data()
        for value in self.storage {
            value.encode(to: &data)
        }
        return data
    }

    func encode(_ value: Int8) throws {
        storage.append(.init(value))
    }

    func encode(_ value: String, isLong: Bool) throws {
        storage.append(.init(value, isLong: isLong))
    }

    func encode(_ value: Int16) throws {
        storage.append(.init(value))
    }

    func encode(_ value: Int32) throws {
        storage.append(.init(value))
    }

    func encode(_ value: Int64) throws {
        storage.append(.init(value))
    }

    func encode(_ value: Bool) throws {
        storage.append(.init(value))
    }

    func encode(_ value: Date) throws {
        storage.append(.init(value))
    }

    func encode(_ value: [String : AMQP.FieldValue]) throws {
        storage.append(.init(value))
    }
}
