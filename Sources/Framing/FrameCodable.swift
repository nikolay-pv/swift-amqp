import Foundation  // for Date

protocol FrameDecoderProtocol {
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
    func decode(_ type: [String: Spec.FieldValue].Type) throws -> [String: Spec.FieldValue]
    func decode(_ type: [Spec.FieldValue].Type) throws -> [Spec.FieldValue]
    func decode(_ type: [UInt8].Type) throws -> [UInt8]
}

protocol FrameDecodable {
    init(from decoder: FrameDecoderProtocol) throws
}

protocol FrameEncoderProtocol {
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
    func encode(_ value: [String: Spec.FieldValue]) throws
}

protocol FrameEncodable {
    func encode(to encoder: FrameEncoderProtocol) throws
    /// returns the number of bytes this object will occupy when serialized
    /// NOTE: depending on the object and implementation it might be more than O(1) time
    var bytesCount: UInt32 { get }
}

protocol FrameCodable: Sendable, FrameDecodable, FrameEncodable, Equatable {}

extension FrameCodable where Self: Equatable {
    func isEqual(to other: any FrameCodable) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}
