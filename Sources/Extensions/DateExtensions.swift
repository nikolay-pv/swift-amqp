//
//  DateExtensions.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 13.10.2024.
//

import Foundation

extension Date {
    var millisecondsSince1970: UInt64 { UInt64((self.timeIntervalSince1970 * 1000.0).rounded()) }

    init(millisecondsSince1970: UInt64) {
        self = Date(timeIntervalSince1970: TimeInterval(millisecondsSince1970) / 1000)
    }
}
