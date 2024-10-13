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

    mutating func append(_ value: Int16) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    mutating func append(_ value: Int32) {
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
        switch self {
        case .octet(_):
            data.append(contentsOf: "b".utf8)
            self.asWrappedValue.encode(to: &data)
        case .shortstr(_):
            data.append(contentsOf: "S".utf8)
            self.asWrappedValue.encode(to: &data)
        case .longstr(_):
            data.append(contentsOf: "S".utf8)
            self.asWrappedValue.encode(to: &data)
        case .short(_):
            data.append(contentsOf: "s".utf8)
            self.asWrappedValue.encode(to: &data)
        case .long(_):
            data.append(contentsOf: "l".utf8)
            self.asWrappedValue.encode(to: &data)
        case .longlong(_):
            data.append(contentsOf: "D".utf8)
            self.asWrappedValue.encode(to: &data)
        case .bit(_):
            data.append(contentsOf: "t".utf8)
            self.asWrappedValue.encode(to: &data)
        case .timestamp(_):
            data.append(contentsOf: "T".utf8)
            self.asWrappedValue.encode(to: &data)
        }
    }

    var asWrappedValue: _FrameEncoder.WrappedValue {
        return switch self {
        case .octet(let value): .int8(value)
        case .shortstr(let value): .shortstring(value)
        case .longstr(let value): .longstring(value)
        case .short(let value): .int16(value)
        case .long(let value): .int32(value)
        case .longlong(let value): .int64(value)
        case .bit(let value): .bool(value)
        case .timestamp(let value): .date(value)
        }
    }
}

private class _FrameEncoder : AMQPEncoder {
    enum WrappedValue: Equatable {
        case shortstring(String)
        case longstring(String)
        case int8(Int8)
        case int16(Int16)
        case int32(Int32)
        case int64(Int64)
        case bool(Bool)
        case date(Date)
        case dictionary([String : AMQP.FieldValue])

        func encode(to data: inout Data) {
            switch self {
            case .shortstring(let value), .longstring(let value):
                withUnsafeBytes(of: value.count.bigEndian) {
                    data.append(contentsOf: $0)
                }
                data.append(contentsOf: value.utf8)
            case .int8(let value):
                data.append(value.bigEndian)
            case .int16(let value):
                data.append(value.bigEndian)
            case .int32(let value):
                data.append(value.bigEndian)
            case .int64(let value):
                data.append(value.bigEndian)
            case .bool(let value):
                data.append(Int8(value ? 1 : 0))
            case .date(let value):
                let milliseconds = value.millisecondsSince1970
                data.append(milliseconds.bigEndian)
            case .dictionary(let table):
                if table.isEmpty {
                    data.append(Int16(0))
                }
                for (key, value) in table {
                    withUnsafeBytes(of: key.shortSize.bigEndian) {
                        data.append(contentsOf: $0)
                    }
                    data.append(contentsOf: key.utf8)
                    value.asWrappedValue.encode(to: &data)
                }
            }
        }

        var size: Int {
            switch self {
            case .shortstring(let value): return value.shortSize
            case .longstring(let value): return value.longSize
            case .bool: return 1
            case .int8: return 1
            case .int16: return 2
            case .int32: return 4
            case .int64: return 8
            case .date: return 8
            case .dictionary(let table): return table.reduce(into: 0) { (partialResult: inout Int, pair) in
                partialResult += pair.key.shortSize + pair.value.size
            }
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
            self = .date(value)
        }
        init (_ value: [String : AMQP.FieldValue]) {
            self = .dictionary(value)
        }
    }
    var storage = [WrappedValue]()

    func complete() -> Data {
        let expectedSize = self.storage.reduce(into: 0) {
            $0 += $1.size
        }
        var data = Data(capacity: expectedSize)
        for value in self.storage {
            value.encode(to: &data)
        }
        precondition(data.count == expectedSize)
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
