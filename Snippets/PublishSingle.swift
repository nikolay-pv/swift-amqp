import AMQP

// this example requires running AMQP server
let publisher = Task {
    // explicit call to close connection and channel
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
    do {
        try await channel.exchangeDeclare(named: exchangeName)
        _ = try await channel.queueDeclare(named: queueName)
        try await channel.queueBind(queue: queueName, exchange: exchangeName, routingKey: queueName)
        try await channel.basicPublish(exchange: exchangeName, routingKey: queueName, body: "ping")
        print("======= Publisher sent message: ping")
    } catch {
        print("Failed to publish message: \(error)")
        return false
    }
    do {
        try await channel.close()
        try await connection.close()
    } catch {
        print("Failed to close connection and channel: \(error)")
        return false
    }
    return true
}
async let _ = publisher.result
