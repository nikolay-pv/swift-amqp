import AMQP
import Foundation

// this example requires running AMQP server
let publisher = Task {
    let connection = try? await Connection(with: .default)
    guard let connection else {
        fatalError("connection wasn't created")
    }
    let channel = try? await connection.makeChannel()
    guard let channel else {
        fatalError("channel wasn't created")
    }
    let exchangeName = "swift-amqp-exchange"
    let queueName = "swift-amqp-queue"
    try await channel.exchangeDeclare(named: exchangeName)
    _ = try await channel.queueDeclare(named: queueName)
    try await channel.queueBind(queue: queueName, exchange: exchangeName, routingKey: queueName)
    try await channel.basicPublish(exchange: exchangeName, routingKey: queueName, body: "ping")
}
async let _ = publisher.result

let consumer = Task {
    let connection = try? await Connection(with: .default)
    guard let connection else {
        fatalError("connection wasn't created")
    }
    let channel = try? await connection.makeChannel()
    guard let channel else {
        fatalError("channel wasn't created")
    }
    let exchangeName = "swift-amqp-exchange"
    let queueName = "swift-amqp-queue"
    try await channel.exchangeDeclare(named: exchangeName)
    _ = try await channel.queueDeclare(named: queueName)
    try await channel.queueBind(queue: queueName, exchange: exchangeName, routingKey: queueName)
    let messages = try await channel.basicConsume(
        queue: queueName,
        tag: "somerandomtag"
    )
    // the following would never stop running unless an error occurs
    for await mess in messages {
        print("======= Consumer got message: \(mess)")
    }
}
async let _ = consumer.result
