import AMQP

// this example requires running AMQP server
let publisher = Task {
    // using closure based API to ensure close of connection and channel
    try await Connection.connectChannelThenClose(with: .default, andProperties: .init()) { result in
        switch result {
        case .success(let channel):
            let exchangeName = "swift-amqp-exchange"
            let queueName = "swift-amqp-queue"
            try await channel.exchangeDeclare(named: exchangeName)
            _ = try await channel.queueDeclare(named: queueName)
            try await channel.queueBind(queue: queueName, exchange: exchangeName, routingKey: queueName)
            try await channel.basicPublish(exchange: exchangeName, routingKey: queueName, body: "ping")
            print("======= Publisher sent message: ping")
            try await channel.basicPublish(exchange: exchangeName, routingKey: queueName, body: "stop")
            print("======= Publisher sent message: stop")
        case .failure(let error):
            print("Failed to create publisher: \(error)")
        }
    }
}
async let _ = publisher.result

let consumer = Task {
    let connection = try? await Connection(with: .default)
    guard let connection else {
        fatalError("connection wasn't created")
    }
    // use closure based API to ensure close of channel
    try await Channel.withChannel(on: connection) { result in
        switch result {
        case .success(let channel):
            let exchangeName = "swift-amqp-exchange"
            let queueName = "swift-amqp-queue"
            try await channel.exchangeDeclare(named: exchangeName)
            _ = try await channel.queueDeclare(named: queueName)
            try await channel.queueBind(queue: queueName, exchange: exchangeName, routingKey: queueName)
            let messages = try await channel.basicConsume(
                queue: queueName,
                tag: "some-random-tag"
            )
            for try await message in messages {
                print("======= Consumer got message: \(message)")
                if String(decoding: message.body, as: UTF8.self) == "stop" {
                    try await message.ack()
                    break
                }
                try await message.nack(requeue: false)
            }
        case .failure(let error):
            print("Failed to create consumer channel: \(error)")
        }
    }
    // graceful shutdown
    _ = try await connection.close()
}
async let _ = consumer.result
