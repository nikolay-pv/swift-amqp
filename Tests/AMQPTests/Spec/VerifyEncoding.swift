//
//  VerifyEncoding.swift
//  swift-amqp
//
//  Created by Nikolay Petrov on 30.10.2024.
//

import Foundation
import Testing
@testable import AMQP


@Suite struct Confirm2 {
    @Test("AMQP.Basic.Consume encode verification")
    func amqpConfirmSelectOkEncoding() async throws {
        let expected = try fixtureData(for: "Basic.Consume")
        let actual = try FrameEncoder().encode(AMQP.Basic.Consume())
        #expect(actual == expected)
    }
}

