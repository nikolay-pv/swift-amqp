import AMQP

let sleepDuration = 5
let exchangeName = "swift-amqp-direct-log-exchange"

func receiveLogs(withLevel keys: [String]) async throws {
    precondition(!keys.isEmpty)
    let connection = try? await Connection(with: .default)
    guard let connection else {
        fatalError("connection wasn't created")
    }
    let channel = try await connection.makeChannel()
    let result = try await channel.queueDeclare(named: "", exclusive: true)
    let queueName = result.queueName
    for key in keys {
        try await channel.queueBind(queue: queueName, exchange: exchangeName, routingKey: key)
    }
    print(" [<-] Waiting for messages. To exit press CTRL+C")
    let messages = try await channel.basicConsume(queue: queueName, autoAck: true)
    for try await message in messages {
        let bodyStr = String(decoding: message.body, as: UTF8.self)
        print(" [<-] Received 'TBDrouting_key:\(bodyStr)'")
        if bodyStr == "stop" {
            print(" [<-] exiting on 'stop' signal")
            break
        }
    }
}

let consumer = Task {
    try await receiveLogs(withLevel: ["info", "fatal"])
}

// Publisher: sends messages with routing key to direct exchange
let publisher = Task {
    try await Connection.connectChannelThenClose(with: .default, andProperties: .init()) { result in
        switch result {
        case .success(let channel):
            _ = try await channel.exchangeDeclare(named: exchangeName, type: .direct)
            let severities = ["info", "warning", "fatal"]
            let messages = ["Hello World!", "about to send stop signal", "stop"]
            for (level, message) in zip(severities, messages) {
                try await channel.basicPublish(
                    exchange: exchangeName,
                    routingKey: level,
                    body: message
                )
                print(" [->] Sent '\(level):\(message)'")
            }
        case .failure(let error):
            print("Failed to create publisher: \(error)")
        }
    }
}

async let _ = consumer.result
async let _ = publisher.result
