import AMQP
import Foundation

// this example requires running AMQP server
let publisher = Task {
    let connection = try? await Connection(with: .default)
    guard let connection else {
        print("connection wasn't created")
        return false
    }
    let channel = try? await connection.makeChannel()
    guard let channel else {
        print("channel wasn't created")
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
