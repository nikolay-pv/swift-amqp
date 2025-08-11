import AMQP
import Foundation

// this example requires running AMQP server
let publisher = Task {
    let connection: Connection
    do {
        connection = try await Connection(with: .default)
    } catch {
        print("Failed to create connection: \(error)")
        return false
    }
    let channel: Channel
    do {
        channel = try await connection.makeChannel()
    } catch {
        print("Failed to create channel: \(error)")
        return false
    }
    let exchangeName = "swift-amqp-exchange"
    let queueName = "swift-amqp-queue"
    try await channel.exchangeDeclare(named: exchangeName)
    _ = try await channel.queueDeclare(named: queueName)
    try await channel.queueBind(queue: queueName, exchange: exchangeName, routingKey: queueName)
    try await channel.basicPublish(exchange: exchangeName, routingKey: queueName, body: "ping")
    return true
}
async let _ = publisher.result
