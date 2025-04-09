import Foundation
import Testing

@testable import AMQP

@Test func TransportManualTest() async throws {
    // this test requires running AMQP server
    let connection = try await Transport {
        let configuration = AMQPConfiguration.default
        let properties: Spec.Table = [
            "product": .longstr("swift-amqp"),
            "platform": .longstr("swift"),  // TODO: version here or something
            "capabilities": .table([
                "authentication_failure_close": .bool(true),
                "basic.nack": .bool(true),
                "connection.blocked": .bool(true),
                "consumer_cancel_notify": .bool(true),
                "publisher_confirms": .bool(true),
            ]),
            "information": .longstr("website here"),
            // TODO: "version":  of the library
        ]
        return Spec.AMQPNegotiator(config: configuration, properties: properties)
    }
    sleep(10 * 60)
}
