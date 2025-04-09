import Foundation

class FrameDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: FrameDecodable {
        let decoder = _FrameDecoder()
        return try decoder.with(data: data) { try T.init(from: $0) }
    }
}

extension Spec.FieldValue {
    fileprivate static let charToValue: [UInt8: Spec.FieldValue] = {
        return Self.allCases.reduce(into: [:]) { $0[$1.type] = $1 }
    }()

    fileprivate func decode(from decoder: FrameDecoderProtocol) throws -> Self {
        switch self {
        case .int32: return .int32(try decoder.decode(Int32.self))
        case .decimal:
            let scale = try decoder.decode(UInt8.self)
            let value = try decoder.decode(Int32.self)
            return .decimal(scale, value)
        case .longstr: return .longstr(try decoder.decode(String.self, isLong: true))
        case .timestamp: return .timestamp(try decoder.decode(Date.self))
        case .table: return .table(try decoder.decode(Spec.Table.self))
        case .void:
            let _ = try decoder.decode(UInt8.self)
            return .void
        case .bool: return .bool(try decoder.decode(Bool.self))
        case .int8: return .int8(try decoder.decode(Int8.self))
        case .uint8: return .uint8(try decoder.decode(UInt8.self))
        case .int16: return .int16(try decoder.decode(Int16.self))
        case .uint16: return .uint16(try decoder.decode(UInt16.self))
        case .uint32: return .uint32(try decoder.decode(UInt32.self))
        case .int64: return .int64(try decoder.decode(Int64.self))
        // case .uint64: return .uint64(try decoder.decode(UInt64.self))
        case .f32: return .f32(try decoder.decode(Float.self))
        case .f64: return .f64(try decoder.decode(Double.self))
        // case .shortstr: return .shortstr(try decoder.decode(String.self, isLong: false))
        case .array: return .array(try decoder.decode([Spec.FieldValue].self))
        case .bytes: return .bytes(try decoder.decode(Data.self))
        }
    }
}

private class _FrameDecoder: FrameDecoderProtocol {
    private var _data = Data()
    private var _position: Int = 0

    private func _reset() {
        _position = 0
        _data = Data()
    }

    func with<T>(data: Data, closure: (FrameDecoderProtocol) throws -> T) throws -> T
    where T: FrameDecodable {
        self._data = data
        defer { self._reset() }
        return try closure(self)
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        precondition(_position + 1 <= _data.count)
        defer { _position += 1 }
        return _data[_position] != 0
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        let offset = 1
        precondition(_position + offset <= _data.count)
        defer { _position += offset }
        return .init(
            bigEndian: _data.subdata(in: _position..<_position + offset)
                .withUnsafeBytes { $0.load(as: type) }
        )
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        let offset = 2
        precondition(_position + offset <= _data.count)
        defer { _position += offset }
        return .init(
            bigEndian: _data.subdata(in: _position..<_position + offset)
                .withUnsafeBytes { $0.load(as: type) }
        )
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        let offset = 4
        precondition(_position + offset <= _data.count)
        defer { _position += offset }
        return .init(
            bigEndian: _data.subdata(in: _position..<_position + offset)
                .withUnsafeBytes { $0.load(as: type) }
        )
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        let offset = 8
        precondition(_position + offset <= _data.count)
        defer { _position += offset }
        return .init(
            bigEndian: _data.subdata(in: _position..<_position + offset)
                .withUnsafeBytes { $0.load(as: type) }
        )
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        let offset = 1
        precondition(_position + offset <= _data.count)
        defer { _position += offset }
        return .init(
            bigEndian: _data.subdata(in: _position..<_position + offset)
                .withUnsafeBytes { $0.load(as: type) }
        )
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        let offset = 2
        precondition(_position + offset <= _data.count)
        defer { _position += offset }
        return .init(
            bigEndian: _data.subdata(in: _position..<_position + offset)
                .withUnsafeBytes { $0.load(as: type) }
        )
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        let offset = 4
        precondition(_position + offset <= _data.count)
        defer { _position += offset }
        return .init(
            bigEndian: _data.subdata(in: _position..<_position + offset)
                .withUnsafeBytes { $0.load(as: type) }
        )
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        let offset = 8
        precondition(_position + offset <= _data.count)
        defer { _position += offset }
        return .init(
            bigEndian: _data.subdata(in: _position..<_position + offset)
                .withUnsafeBytes { $0.load(as: type) }
        )
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
        let length = isLong ? Int(try decode(UInt32.self)) : Int(try decode(UInt8.self))
        precondition(_position + length <= _data.count)
        defer { _position += length }
        return .init(decoding: _data.subdata(in: _position..<_position + length), as: UTF8.self)
    }

    func decode(_ type: [String: Spec.FieldValue].Type) throws -> [String: Spec.FieldValue] {
        let byteCount = Int(try decode(UInt32.self))
        let endPosition = _position + byteCount
        var result = [String: Spec.FieldValue]()
        while _position < endPosition {
            let key = try decode(String.self, isLong: false)
            let value = try decode(Spec.FieldValue.self)
            result[key] = value
        }
        return result
    }

    func decode(_ type: [Spec.FieldValue].Type) throws -> [Spec.FieldValue] {
        let byteCount = Int(try decode(UInt32.self))
        let endPosition = _position + byteCount
        var result = [Spec.FieldValue]()
        while _position <= endPosition {
            result.append(try decode(Spec.FieldValue.self))
        }
        return result
    }

    func decode(_ type: Data.Type) throws -> Data {
        let length = Int(try decode(UInt32.self))
        precondition(_position + length <= _data.count)
        defer { _position += length }
        return _data.subdata(in: _position..<_position + length)
    }

    func decode(_ type: Spec.FieldValue.Type) throws -> Spec.FieldValue {
        let type = try decode(UInt8.self)
        guard let prototype = Spec.FieldValue.charToValue[type] else {
            fatalError("Unknown field value type in frame: \(type)")
        }
        return try prototype.decode(from: self)
    }
}
