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
            let messages = ["ping", "stop"]
            for message in messages {
                try await channel.basicPublish(exchange: exchangeName, routingKey: queueName, body: message)
                print(" [->] sent message: '\(message)'")
            }
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
                print(" [->] received message: \(message)")
                if String(decoding: message.body, as: UTF8.self) == "stop" {
                    try await message.ack()
                    break
                }
                try await message.ack()
            }
        case .failure(let error):
            print("Failed to create consumer channel: \(error)")
        }
    }
    // graceful shutdown
    _ = try await connection.close()
}
async let _ = consumer.result
