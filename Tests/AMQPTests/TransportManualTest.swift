import Foundation
import Testing

@testable import AMQP

@Test func TransportManualTest() async throws {
    // this test requires running AMQP server
    let connection = try? await Connection(with: .default)
    let channel = try? await connection?.makeChannel()
    let exchangeName = "swift-amqp-exchange"
    let queueName = "swift-amqp-queue"
    try await channel?.exchangeDeclare(named: exchangeName)
    try await channel?.queueDeclare(named: queueName)
    try await channel?.basicPublish(exchange: "", routingKey: queueName, body: "ping")
    sleep(10 * 60)
}
