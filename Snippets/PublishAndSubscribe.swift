import AMQP

let sleepDuration = 5
let exchangeName = "swift-amqp-log-exchange"

func receiveLogs() async throws {
    let connection = try? await Connection(with: .default)
    guard let connection else {
        fatalError("connection wasn't created")
    }
    let channel = try await connection.makeChannel()
    let result = try await channel.queueDeclare(named: "", exclusive: true)
    let queueName = result.queueName
    try await channel.queueBind(queue: queueName, exchange: exchangeName)
    print(" [<-] Waiting for messages. To exit press CTRL+C")
    let messages = try await channel.basicConsume(queue: queueName, autoAck: true)
    for try await message in messages {
        let bodyStr = String(decoding: message.body, as: UTF8.self)
        print(" [<-] Received '\(bodyStr)'")
        if bodyStr == "stop" {
            print(" [<-] exiting on 'stop' signal")
            break
        }
    }
}

let consumer = Task {
    try await receiveLogs()
}

let consumer2 = Task {
    try await receiveLogs()
}

// Publisher: sends messages without routing key to fanout exchange
let publisher = Task {
    try await Connection.connectChannelThenClose(with: .default, andProperties: .init()) { result in
        switch result {
        case .success(let channel):
            _ = try await channel.exchangeDeclare(named: exchangeName)
            let messages = ["info: Hello World!", "warning: about to send stop signal", "stop"]
            for message in messages {
                try await channel.basicPublish(exchange: exchangeName, routingKey: "", body: message)
                print(" [->] Sent '\(message)'")
            }
        case .failure(let error):
            print("Failed to create publisher: \(error)")
        }
    }
}

async let _ = consumer.result
async let _ = consumer2.result
async let _ = publisher.result
