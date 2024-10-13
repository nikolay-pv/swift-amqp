//
//  StringExtensions.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 13.10.2024.
//

extension String {
    var isShort: Bool {
        self.utf8.count <= UInt8.max
    }

    var shortSize: Int {
        precondition(isShort, "String is too long")
        return self.utf8.count + 1
    }
    var longSize: Int { self.utf8.count + 4 }
}

