//
//  AMQP+Extensions.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 15.10.2024.
//

extension Spec.Table {
    var bytesCount: UInt32 {
        self.reduce(into: UInt32(0)) { $0 += UInt32($1.key.shortBytesCount) + $1.value.bytesCount }
    }
}
