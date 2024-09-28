//
//  BinaryEncoder.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 28.07.2024.
//

import Foundation

// Linked list traking the path of CodingKey's to current element (used in pushing continaers in coders)
internal enum _CodingPathNode/* : Sendable */{
    case root
    indirect case node(CodingKey, _CodingPathNode, depth: Int)

    var path : [CodingKey] {
        switch self {
        case .root:
            return []
        case let .node(key, parent, _):
            return parent.path + [key]
        }
    }

    @inline(__always)
    var depth: Int {
        switch self {
        case .root: return 0
        case .node(_, _, let depth): return depth
        }
    }

    @inline(__always)
    func appending(key: __owned (some CodingKey)?) -> _CodingPathNode {
        if let key {
            return .node(key, self, depth: self.depth + 1)
        } else {
            return self
        }
    }
}

internal enum _CodingKey : CodingKey {
    case string(String)
    case int(Int)

    @inline(__always)
    public init?(stringValue: String) {
        self = .string(stringValue)
    }

    @inline(__always)
    public init(intValue: Int) {
        self = .int(intValue)
    }

    var stringValue: String {
        switch self {
        case let .int(value): return "\(value)"
        case let .string(key): return key
        }
    }

    var intValue: Int? {
        switch self {
        case let .int(value): return value
        case .string(_): return nil
        }
    }
}

// MARK: - BinaryWriter

internal struct BinaryWriter {
    var data: Data { .init() }

    mutating func serialize(_ ref: BinaryReference) throws {
        // TODO: implement
    }
}

// MARK: - BinaryEncoder

open class BinaryEncoder {
    open func encode<T: Encodable>(_ value: T) throws -> Data {
        try _encode( { try $0.wrap(value) }, value: value)
    }

    private func _encode<T>(_ caller: (_BinaryEncoder) throws -> BinaryReference?, value: T) throws -> Data {
        let encoder = _BinaryEncoder()
        guard let ref = try caller(encoder) else {
            // TODO: handle errors
            fatalError()
        }
        do {
            var writer = BinaryWriter()
            try writer.serialize(ref)
            return writer.data
        } catch let error {
            // TODO: handle errors
            fatalError(error.localizedDescription)

        }
    }
}

private class _BinaryEncoder : Encoder {

    var storage = BinaryEncodingStorage()
    var codingPathNode: _CodingPathNode

    init(codingPathNode: _CodingPathNode = .root, userInfo: [CodingUserInfoKey : Any] = [:]) {
        self.storage = BinaryEncodingStorage()
        self.codingPathNode = codingPathNode
        self.userInfo = userInfo
    }

    // MARK: - Encoder
    var codingPath: [any CodingKey] { codingPathNode.path }
    var userInfo: [CodingUserInfoKey : Any] = [:]

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let root: BinaryReference = {
            if self.canEncode {
                return self.storage.pushKeyedContainer()
            } else {
                guard let ref = self.storage.refs.last, ref.isTable else {
                    // TODO: handle errors
                    preconditionFailure("TODO")
                }
                return ref
            }
        }()
        let container = BinaryKeyedEncodingContainer<Key>(encoder: self, codingPathNode: self.codingPathNode, ref: root)
        return KeyedEncodingContainer<Key>(container)
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        let ref = { [self] in
            if self.canEncode {
                return self.storage.pushUnkeyedContainer()
            } else {
                guard let last = self.storage.last, last.isArray else {
                    // TODO: handle errors
                    preconditionFailure("TODO")
                }
                return last
            }
        }()
        return BinaryUnkeyedEncodingContainer(encoder: self, codingPathNode: self.codingPathNode, ref: ref)
    }

    func singleValueContainer() -> any SingleValueEncodingContainer { self }

    var canEncode: Bool {
        self.storage.count == self.codingPathNode.depth
    }
}

extension _BinaryEncoder {
//    func wrapGeneric<T>(_ value: T, for ref: Node) // todo what Node's will do here?
    func wrap<T>(_ value: T) throws -> BinaryReference {
        // TODO: add implementations here
        .null
    }
}

// MARK: - Encoding Containers
extension _BinaryEncoder: SingleValueEncodingContainer {
    func encodeNil() throws {
        self.storage.pushReference(.null)
    }

    func encode<T>(_ value: T) throws {
        // TODO: do a proper thing here and don't "capture all types"
        self.storage.pushReference(.null)
    }
}

private class BinaryKeyedEncodingContainer<K : CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K

    private let encoder: _BinaryEncoder

    private let ref: BinaryReference
    private let codingPathNode: _CodingPathNode

    public var codingPath: [any CodingKey] {
        codingPathNode.path
    }

    init(encoder: _BinaryEncoder, codingPathNode: _CodingPathNode, ref: BinaryReference) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.ref = ref
    }

    // MARK: - KeyedEncodingContainerProtocol
    func encodeNil(forKey key: K) throws {
        self.ref.insert(.null, for: key.stringValue)
    }

    // TODO: make this concrete type
    func encode<T>(_ value: T, forKey key: K) throws {
        self.ref.insert(try self.encoder.wrap(value), for: key.stringValue)
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let keyString = key.stringValue
        let requestedRef: BinaryReference
        if let existingRef = self.ref[keyString] {
            precondition(existingRef.isTable, "Encoding into nested container for key \(key) is invalid for non-keyed container already encoded for this key")
            requestedRef = existingRef
        } else {
            requestedRef = .emptyTable
            self.ref.insert(requestedRef, for: keyString)
        }
        let container = BinaryKeyedEncodingContainer<NestedKey>(encoder: self.encoder, codingPathNode: self.codingPathNode.appending(key: key), ref: requestedRef)
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: K) -> any UnkeyedEncodingContainer {
        let keyString = key.stringValue
        let requestedRef: BinaryReference
        if let existingRef = self.ref[keyString] {
            precondition(existingRef.isArray, "TODO")
            requestedRef = existingRef
        } else {
            requestedRef = .emptyArray
            self.ref.insert(requestedRef, for: keyString)
        }
        return BinaryUnkeyedEncodingContainer(encoder: self.encoder, codingPathNode: self.codingPathNode.appending(key: key), ref: requestedRef)
    }

    func superEncoder() -> any Encoder {
        // TODO: implement this properly
//        return _BinaryEncoder()
        fatalError()
    }

    func superEncoder(forKey key: K) -> any Encoder {
        // TODO: implement this properly
//        return _BinaryEncoder()
        fatalError()
    }
}

private class BinaryUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    private let encoder: _BinaryEncoder

    private let ref: BinaryReference
    private let codingPathNode: _CodingPathNode

    public var codingPath: [any CodingKey] {
        codingPathNode.path
    }

    public var count: Int {
        self.ref.count
    }

    // MARK: - init

    init(encoder: _BinaryEncoder, codingPathNode: _CodingPathNode, ref: BinaryReference) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.ref = ref
    }

    // MARK: - UnkeyedEncodingContainer

    public func encodeNil() throws {
        self.ref.append(.null)
    }

    public func encode(_ value: Bool) throws { self.ref.append(try self.encoder.wrap(value)) }
    public func encode(_ value: Int) throws { self.ref.append(try self.encoder.wrap(value)) }
    public func encode(_ value: String) throws { self.ref.append(try self.encoder.wrap(value)) }
    // TODO: add concrete types instead
    public func encode<T>(_ value: T) throws { self.ref.append(try self.encoder.wrap(value)) }

    // MARK: - pushing Containers
    public func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let key = _CodingKey(intValue: self.count)
        let nestedRef = BinaryReference.emptyTable
        self.ref.append(nestedRef)
        let container = BinaryKeyedEncodingContainer<NestedKey>(encoder: self.encoder, codingPathNode: self.codingPathNode.appending(key: key), ref: self.ref)
        return KeyedEncodingContainer(container)
    }

    public func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        let key = _CodingKey(intValue: self.count)
        let nestedRef = BinaryReference.emptyArray
        self.ref.append(nestedRef)
        let container = BinaryUnkeyedEncodingContainer(encoder: self.encoder, codingPathNode: self.codingPathNode.appending(key: key), ref: self.ref)
        return container
    }

    public func superEncoder() -> any Encoder {
        // TODO: implement this properly
        return _BinaryEncoder()
    }
}

// MARK: - BinaryReference and Storage for them

internal class BinaryReference {
    enum UnderlyingType {
        // strings
        // according to https://www.rabbitmq.com/resources/specs/amqp-xml-doc0-9-1.pdf
        case shortstr(String),
             longstr(String),
             // logical
             bit(Bool),
             // ints
             octet(UInt8),
             short(Int16),
             long(Int32),
             longlong(Int64),
             // time
             timestamp(Int64),
             // composites
             array([BinaryReference]),
             table([String:BinaryReference]),
             // meta
             null
    }

    private(set) var value: UnderlyingType

    init(_ value: UnderlyingType) {
        self.value = value
    }

    func insert(_ ref: BinaryReference, for key: String) {
        guard case .table(var dict) = value else {
            preconditionFailure("Can't insert reference into non-containerised value")
        }
        // reset to maintain single onwer of the dict
        value = .null
        dict[key] = ref
        value = .table(dict)
    }

    func insert(_ ref: BinaryReference, at index: Int) {
        guard case .array(var container) = value else {
            preconditionFailure("Can't insert reference into non-containerised value")
        }
        // reset to maintain single onwer of the container
        value = .null
        container[index] = ref
        value = .array(container)
    }

    func append(_ ref: BinaryReference) {
        guard case .array(var container) = value else {
            preconditionFailure("Can't insert reference into non-containerised value")
        }
        // reset to maintain single onwer of the container
        value = .null
        container.append(ref)
        value = .array(container)
    }

    subscript(_ key: String) -> BinaryReference? {
        guard case .table(let dict) = value else {
            preconditionFailure("Can't subscript reference to non-containerised value")
        }
        return dict[key]
    }

    subscript(_ index: Int) -> BinaryReference {
        guard case .array(let container) = value else {
            preconditionFailure("Can't subscript reference to non-containerised value")
        }
        return container[index]
    }

    var isTable: Bool {
        guard case .table = value else {
            return false
        }
        return true
    }

    var isArray: Bool {
        guard case .array = value else {
            return false
        }
        return true
    }

    var count: Int {
        switch value {
        case .array(let array): return array.count
        case .table(let dict): return dict.count
        default: preconditionFailure("Can't count references in non-containerised value")
        }
    }

    // static const objects -> nonisolated
    nonisolated(unsafe) static let null : BinaryReference = .init(.null)
    nonisolated(unsafe) static let emptyTable : BinaryReference = .init(.table([:]))
    nonisolated(unsafe) static let emptyArray : BinaryReference = .init(.array([]))
}

private struct BinaryEncodingStorage {
    var refs = [BinaryReference]()

    var last: BinaryReference? { refs.last }
    var count: Int { refs.count }

    mutating func pushKeyedContainer() -> BinaryReference {
        let object = BinaryReference.emptyTable
        refs.append(object)
        return object
    }

    mutating func pushUnkeyedContainer() -> BinaryReference {
        let object = BinaryReference.emptyArray
        refs.append(object)
        return object
    }

    mutating func pushReference(_ ref: BinaryReference) {
        refs.append(ref)
    }

    mutating func pop() -> BinaryReference {
        precondition(!refs.isEmpty, "called pop on empty storage")
        return refs.popLast().unsafelyUnwrapped
    }
}
