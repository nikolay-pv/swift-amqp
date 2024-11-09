//
//  StringExtensions.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 13.10.2024.
//

extension String {
    var isShort: Bool {
        self.utf8.count <= UInt8.max - 1
    }

    var shortBytesCount: UInt8 {
        let size = UInt8(self.utf8.count)
        precondition(size <= UInt8.max - 1, "String is too long")
        return size
    }
    var longBytesCount: UInt32 {
        let size = UInt32(self.utf8.count)
        precondition(self.utf8.count <= UInt32.max - 4, "String is too long")
        return size
    }
}
