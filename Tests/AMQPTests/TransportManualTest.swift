import Foundation
import Testing

@testable import AMQP

@Test func TransportManualTest() async throws {
    // this test requires running AMQP server
    let connection = try? await Connection(with: .default)
    #expect(connection != nil)
    let channel = try? await connection?.makeChannel()
    #expect(channel != nil)
    let exchangeName = "swift-amqp-exchange"
    let queueName = "swift-amqp-queue"
    guard let channel else {
        fatalError("channel wasn't created")
    }
    try await channel.exchangeDeclare(named: exchangeName)
    _ = try await channel.queueDeclare(named: queueName)
    try await channel.queueBind(queue: queueName, exchange: exchangeName, routingKey: queueName)
    try await channel.basicPublish(exchange: exchangeName, routingKey: queueName, body: "ping")
    sleep(3)
}
