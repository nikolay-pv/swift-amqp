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
        let encoded = try FrameEncoder().encode(AMQP.Basic.Consume())
        #expect(encoded == expected)
    }

    @Test("AMQP.Basic.Consume decode verification")
    func amqpConfirmSelectOkDecoding() async throws {
        let input = try fixtureData(for: "Basic.Consume")
        let decoded = try FrameDecoder().decode(AMQP.Basic.Consume.self, from: input)
        let expected = AMQP.Basic.Consume()
        #expect(decoded == expected)
    }
}

