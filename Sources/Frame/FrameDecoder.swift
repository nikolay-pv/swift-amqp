//
//  FrameDecoder.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 13.10.2024.
//

import Foundation

class FrameDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: AMQPDecodable {
        let decoder = _FrameDecoder()
        return try decoder.with(data: data) {
            try T.init(from: $0)
        }
    }
}

fileprivate extension AMQP.FieldValue {
    static let charToValue: [UInt8: AMQP.FieldValue] = {
        return Self.allCases.reduce(into: [:]) {
            $0[$1.type] = $1
        }
    } ()

    func decode(from decoder: AMQPDecoder) throws -> Self {
        switch self {
        case .long(_):
            return .long(try decoder.decode(Int32.self))
        case .decimal(_, _):
            let scale = try decoder.decode(UInt8.self)
            let value = try decoder.decode(Int32.self)
            return .decimal(scale, value)
        case .longstr(_):
            return .longstr(try decoder.decode(String.self, isLong: true))
        case .timestamp(_):
            return .timestamp(try decoder.decode(Date.self))
        case .table(_):
            return .table(try decoder.decode(AMQP.Table.self))
        case .void:
            let _ = try decoder.decode(UInt8.self)
            return .void
        }
    }
}

fileprivate class _FrameDecoder: AMQPDecoder {
    // TODO: any better way?
    private var _data: Data?
    var data: Data {
        get { return _data ?? Data() }
        set {
            _data = newValue
            _position = 0
        }
    }

    private var _position: Int = 0

    private func _reset() {
        _position = 0
        _data = nil
    }

    func with<T>(data: Data, closure: (AMQPDecoder) throws -> T) throws -> T where T: AMQPDecodable {
        self.data = data
        defer { self._reset() }
        return try closure(self)
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        precondition(_position + 1 <= data.count)
        defer { _position += 1 }
        return data[_position] != 0
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        let offset = 1
        precondition(_position + offset <= data.count)
        defer { _position += offset }
        return .init(bigEndian: data.subdata(in: _position..<_position + offset).withUnsafeBytes {
            $0.load(as: type)
        })
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        let offset = 2
        precondition(_position + offset <= data.count)
        defer { _position += offset }
        return .init(bigEndian: data.subdata(in: _position..<_position + offset).withUnsafeBytes {
            $0.load(as: type)
        })
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        let offset = 4
        precondition(_position + offset <= data.count)
        defer { _position += offset }
        return .init(bigEndian: data.subdata(in: _position..<_position + offset).withUnsafeBytes {
            $0.load(as: type)
        })
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        let offset = 8
        precondition(_position + offset <= data.count)
        defer { _position += offset }
        return .init(bigEndian: data.subdata(in: _position..<_position + offset).withUnsafeBytes {
            $0.load(as: type)
        })
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        let offset = 1
        precondition(_position + offset <= data.count)
        defer { _position += offset }
        return .init(bigEndian: data.subdata(in: _position..<_position + offset).withUnsafeBytes {
            $0.load(as: type)
        })
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        let offset = 2
        precondition(_position + offset <= data.count)
        defer { _position += offset }
        return .init(bigEndian: data.subdata(in: _position..<_position + offset).withUnsafeBytes {
            $0.load(as: type)
        })
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        let offset = 4
        precondition(_position + offset <= data.count)
        defer { _position += offset }
        return .init(bigEndian: data.subdata(in: _position..<_position + offset).withUnsafeBytes {
            $0.load(as: type)
        })
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        let offset = 8
        precondition(_position + offset <= data.count)
        defer { _position += offset }
        return .init(bigEndian: data.subdata(in: _position..<_position + offset).withUnsafeBytes {
            $0.load(as: type)
        })
    }

    func decode(_ type: Float.Type) throws -> Float {
        return .init(bitPattern: try decode(UInt32.self))
    }

    func decode(_ type: Double.Type) throws -> Double {
        return .init(bitPattern: try decode(UInt64.self))
    }

    func decode(_ type: Date.Type) throws -> Date {
        return .init(millisecondsSince1970: try decode(UInt64.self))
    }

    func decode(_ type: String.Type, isLong: Bool) throws -> String {
        let count = isLong ? Int(try decode(UInt32.self)) : Int(try decode(UInt8.self))
        precondition(_position + count <= data.count)
        defer { _position += count }
        return .init(
            decoding: data.subdata(in: _position..<_position + count),
            as: UTF8.self
        )
    }

    func decode(_ type: [String : AMQP.FieldValue].Type) throws -> [String : AMQP.FieldValue] {
        let count = Int(try decode(UInt16.self))
        defer { _position += count }
        return try (0..<count).reduce(into: [String : AMQP.FieldValue]()) { d, _ in
            let key = try decode(String.self, isLong: false)
            let value = try decode(AMQP.FieldValue.self)
            d[key] = value
        }
    }

    func decode(_ type: AMQP.FieldValue.Type) throws -> AMQP.FieldValue {
        let type = try decode(UInt8.self)
        guard let prototype = AMQP.FieldValue.charToValue[type] else {
            fatalError("Unknown field value type in frame: \(type)")
        }
        return try prototype.decode(from: self)
    }
}
