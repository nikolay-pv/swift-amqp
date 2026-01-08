import Foundation  // for Date

class FrameEncoder {
    func encode<T>(_ value: T) throws -> ByteArray where T: FrameEncodable {
        let encoder = _FrameEncoder()
        try value.encode(to: encoder)
        return encoder.complete()
    }
}

extension Spec.FieldValue {
    fileprivate func encode(to data: inout ByteArray) throws {
        data.writeInteger(self.type)
        self.asWrappedValue.encode(to: &data)
    }

    fileprivate var asWrappedValue: _FrameEncoder.WrappedValue {
        return switch self {
        case .int32(let value): .int32(value)
        case .decimal(let scale, let value): .decimal(scale, value)
        case .longstr(let value): .longstring(value)
        case .timestamp(let value): .timestamp(value)
        case .table(let value): .dictionary(value)
        case .void: .void(self.type)
        case .bool(let value): .bool(value)
        case .int8(let value): .int8(value)
        case .uint8(let value): .uint8(value)
        case .int16(let value): .int16(value)
        case .uint16(let value): .uint16(value)
        case .uint32(let value): .uint32(value)
        case .int64(let value): .int64(value)
        // case .uint64(let value): .uint64(value)
        case .f32(let value): .float(value)
        case .f64(let value): .double(value)
        // case .shortstr(let value): .shortstring(value)
        case .array(let value): .array(value.map(\.asWrappedValue))
        case .bytes(let value): .data(value)
        }
    }
}

private class _FrameEncoder: FrameEncoderProtocol {
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
        case dictionary(Spec.Table)
        case void(UInt8)  // only for field values
        case decimal(UInt8, Int32)  // only for field values
        case array([WrappedValue])  // only for field values
        case data([UInt8])  // only for field values

        // swiftlint:disable:next cyclomatic_complexity
        func encode(to data: inout ByteArray) {
            switch self {
            case .shortstring(let value):
                data.writeInteger(UInt8(value.count), endianness: .big)
                data.writeBytes(value.utf8)
            case .longstring(let value):
                data.writeInteger(UInt32(value.count), endianness: .big)
                data.writeBytes(value.utf8)
            case .uint8(let value): data.writeInteger(value, endianness: .big)
            case .int8(let value): data.writeInteger(value, endianness: .big)
            case .uint16(let value): data.writeInteger(value, endianness: .big)
            case .int16(let value): data.writeInteger(value, endianness: .big)
            case .uint32(let value): data.writeInteger(value, endianness: .big)
            case .int32(let value): data.writeInteger(value, endianness: .big)
            case .uint64(let value): data.writeInteger(value, endianness: .big)
            case .int64(let value): data.writeInteger(value, endianness: .big)
            case .bool(let value): data.writeInteger(UInt8(value ? 1 : 0))
            case .float(let value): data.writeInteger(UInt32(value.bitPattern), endianness: .big)
            case .double(let value): data.writeInteger(UInt64(value.bitPattern), endianness: .big)
            case .timestamp(let value):
                let milliseconds = value.millisecondsSince1970
                data.writeInteger(milliseconds, endianness: .big)
            case .dictionary(let table):
                precondition(table.count <= UInt16.max)
                // 4 bytes are needed to store the size of the Table
                data.writeInteger((table.bytesCount - 4), endianness: .big)
                for (key, value) in table {
                    WrappedValue.shortstring(key).encode(to: &data)
                    data.writeInteger(value.type, endianness: .big)
                    value.asWrappedValue.encode(to: &data)
                }
            case .void(let value): data.writeInteger(value)
            case .decimal(let scale, let value):
                data.writeInteger(scale, endianness: .big)
                data.writeInteger(value, endianness: .big)
            case .array(let value):
                data.writeInteger(UInt32(value.count), endianness: .big)
                value.forEach { $0.encode(to: &data) }
            case .data(let value):
                data.writeInteger(UInt32(value.count), endianness: .big)
                data.writeBytes(value)
            }
        }

        var bytesCount: Int {
            return switch self {
            case .shortstring(let value): Int(value.shortBytesCount)
            case .longstring(let value): Int(value.longBytesCount)
            case .bool, .int8, .uint8, .void: 1
            case .int16, .uint16: 2
            case .int32, .uint32, .float: 4
            case .decimal: 5
            case .int64, .uint64, .timestamp, .double: 8
            case .dictionary(let value): Int(value.bytesCount)
            case .array(let value): Int(value.reduce(into: 0) { $0 += $1.bytesCount }) + 4  // UInt32 for length
            case .data(let value): Int(value.count) + 4  // UInt32 for length
            }
        }
    }
    var storage = [WrappedValue]()

    func complete() -> ByteArray {
        var data: ByteArray = .init()
        let expectedCapacity = self.storage.reduce(into: 0) { $0 += $1.bytesCount }
        data.reserveCapacity(expectedCapacity)
        for value in self.storage {
            value.encode(to: &data)
        }
        return data
    }

    func encode(_ value: Bool) throws {
        storage.append(.bool(value))
    }

    func encode(_ value: Int8) throws {
        storage.append(.int8(value))
    }

    func encode(_ value: Int16) throws {
        storage.append(.int16(value))
    }

    func encode(_ value: Int32) throws {
        storage.append(.int32(value))
    }

    func encode(_ value: Int64) throws {
        storage.append(.int64(value))
    }

    func encode(_ value: UInt8) throws {
        storage.append(.uint8(value))
    }

    func encode(_ value: UInt16) throws {
        storage.append(.uint16(value))
    }

    func encode(_ value: UInt32) throws {
        storage.append(.uint32(value))
    }

    func encode(_ value: UInt64) throws {
        storage.append(.uint64(value))
    }

    func encode(_ value: Float) throws {
        storage.append(.float(value))
    }

    func encode(_ value: Double) throws {
        storage.append(.double(value))
    }

    func encode(_ value: Date) throws {
        storage.append(.timestamp(value))
    }

    func encode(_ value: String, isLong: Bool) throws {
        storage.append(isLong ? .longstring(value) : .shortstring(value))
    }

    func encode(_ value: [String: Spec.FieldValue]) throws {
        storage.append(.dictionary(value))
    }
}
