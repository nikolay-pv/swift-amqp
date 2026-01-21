import AMQP

let sleepDuration = 5
let queueName = "swift-amqp-work-queue"

// Publisher: sends messages with varying number of dots to simulate work
let publisher = Task {
    try await Connection.connectChannelThenClose(with: .default, andProperties: .init()) { result in
        switch result {
        case .success(let channel):
            _ = try await channel.queueDeclare(named: queueName)
            let messages = ["Hello" + String(repeating: ".", count: sleepDuration), "stop"]
            for message in messages {
                try await channel.basicPublish(exchange: "", routingKey: queueName, body: message)
                print(" [->] Sent '\(message)'")
            }
        case .failure(let error):
            print("Failed to create publisher: \(error)")
        }
    }
}
async let _ = publisher.result

// Consumer: waits for messages, sleeps one second per dot, and acks, then stops when "stop" message is received
let consumer = Task {
    try await Connection.connectChannelThenClose(with: .default, andProperties: .init()) { result in
        switch result {
        case .success(let channel):
            _ = try await channel.queueDeclare(named: queueName)
            try await channel.basicQos(prefetchCount: 1)
            print(" [<-] Waiting for messages. To exit press CTRL+C")
            let messages = try await channel.basicConsume(queue: queueName, tag: "work-queue-tag")
            for try await message in messages {
                if String(decoding: message.body, as: UTF8.self) == "stop" {
                    print(" [<-] Received 'stop' signal, exiting")
                    try await message.ack()
                    break
                }
                let bodyStr = String(decoding: message.body, as: UTF8.self)
                print(" [<-] Received '\(bodyStr)'")
                let dotsCount = bodyStr.filter { $0 == "." }.count
                print(" [<-] Sleep for \(dotsCount)s")
                try await Task.sleep(nanoseconds: UInt64(dotsCount) * 1_000_000_000)
                print(" [<-] Done sleeping")
                try await message.ack()
            }
        case .failure(let error):
            print("Failed to create consumer channel: \(error)")
        }
    }
}
async let _ = consumer.result
