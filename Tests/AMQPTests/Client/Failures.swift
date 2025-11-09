import Testing

@testable import AMQP

@Suite struct Failures {

    @Test("Can't use channel after closing the Connection")
    func channelStopsWorkingUponConnectionClosure() async throws {
        let expectedChannelId: UInt16 = 1
        let actions: [TransportMock.Action] = [
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.Open()
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.OpenOk()
                )
            ),
            .outbound(
                MethodFrame(
                    channelId: 0,
                    payload: Spec.Connection.Close(
                        replyCode: 0,
                        replyText: "",
                        classId: 0,
                        methodId: 0
                    )
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: 0,
                    payload: Spec.Connection.CloseOk()
                )
            ),
        ]
        let env = makeTestEnv(with: actions)
        var channel: Channel?
        do {
            let connection = try await Connection(with: .default, env: env)
            channel = try? await connection.makeChannel()
            try await connection.close()
        } catch {
            #expect(Bool(false), "Connection should succeed")
        }
        #expect(channel != nil)
        try await #require(
            throws: ConnectionError.connectionIsClosed
        ) {
            let _ = try await channel!.queueDeclare(named: "test")
        }
    }

    @Test("Can't use channel after closing it")
    func channelStopsWorkingUponItsClosure() async throws {
        let expectedChannelId: UInt16 = 1
        let actions: [TransportMock.Action] = [
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.Open()
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.OpenOk()
                )
            ),
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.Close(
                        replyCode: 0,
                        replyText: "",
                        classId: 0,
                        methodId: 0
                    )
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.CloseOk()
                )
            ),
        ]
        let env = makeTestEnv(with: actions)
        let connection = try? await Connection(with: .default, env: env)
        let channel = try? await connection?.makeChannel()
        #expect(connection != nil)
        #expect(channel != nil)
        await #expect(throws: Never.self) {
            try await channel?.close()
        }
        #expect(!connection!.isOpen)
        try await #require(
            throws: ConnectionError.channelIsClosed
        ) {
            let _ = try await channel!.queueDeclare(named: "test")
        }
    }

    @Test("Can't create more channels than negotiated limit")
    func cannotCreateMoreChannelsThanNegotiatedLimit() async throws {
        let expectedChannelId: UInt16 = 1
        let actions: [TransportMock.Action] = [
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.Open()
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.OpenOk()
                )
            ),
            .keepAlive,
        ]
        let env = makeTestEnv(
            with: actions,
            customizingNegotiatedProperties: {
                var (config, props) = $0
                config.maxChannelCount = 1
                return (config, props)
            }
        )
        let connection = try await Connection(with: .default, env: env)
        let channel = try await connection.makeChannel()

        #expect(connection.isOpen)
        #expect(channel.isOpen)
        try await #require(
            throws: ConnectionError.maxChannelsLimitReached
        ) {
            let _ = try await connection.makeChannel()
        }
        // the connection should remain open
        #expect(connection.isOpen)
    }

    @Test("Can recreate more channels within negotiated limit")
    func recreateChannelsWithinNegotiatedLimit() async throws {
        let expectedChannelId: UInt16 = 1
        let actions: [TransportMock.Action] = [
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.Open()
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.OpenOk()
                )
            ),
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.Close(
                        replyCode: 0,
                        replyText: "",
                        classId: 0,
                        methodId: 0
                    )
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.CloseOk()
                )
            ),
            // reuse same id
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.Open()
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.OpenOk()
                )
            ),
            .keepAlive,
        ]
        let env = makeTestEnv(
            with: actions,
            customizingNegotiatedProperties: {
                var (config, props) = $0
                config.maxChannelCount = 1
                return (config, props)
            }
        )
        let connection = try await Connection(with: .default, env: env)
        #expect(connection.isOpen)
        do {
            let channel = try await connection.makeChannel()
            try await channel.close()
        }
        #expect(connection.isOpen)
        // create channel again
        let _ = try await connection.makeChannel()
        // the connection should remain open
        #expect(connection.isOpen)
    }

    @Test("Can't receive frames larger the agreed frame size limit")
    func connectionDropsUponExceedingFrameSizeLimit() async throws {
        let expectedChannelId: UInt16 = 1
        let actions: [TransportMock.Action] = [
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.Open()
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: Spec.Channel.OpenOk()
                )
            ),
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: AMQP.Spec.Exchange.Declare(
                        exchange: "swift-amqp-exchange",
                        durable: true
                    )
                )
            ),
            .inbound(
                MethodFrame(channelId: expectedChannelId, payload: AMQP.Spec.Exchange.DeclareOk())
            ),
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: AMQP.Spec.Queue.Declare(
                        queue: "swift-amqp-queue",
                        durable: true
                    )
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: AMQP.Spec.Queue.DeclareOk(
                        queue: "swift-amqp-queue",
                        messageCount: 0,
                        consumerCount: 0
                    )
                )
            ),
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: AMQP.Spec.Queue.Bind(
                        queue: "swift-amqp-queue",
                        exchange: "swift-amqp-exchange",
                        routingKey: "swift-amqp-queue"
                    )
                )
            ),
            .inbound(
                MethodFrame(channelId: expectedChannelId, payload: AMQP.Spec.Queue.BindOk())
            ),
            .outbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: AMQP.Spec.Basic.Consume(
                        queue: "swift-amqp-queue",
                        consumerTag: "somerandomtag"
                    )
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: AMQP.Spec.Basic.ConsumeOk(consumerTag: "somerandomtag")
                )
            ),
            .inbound(
                MethodFrame(
                    channelId: expectedChannelId,
                    payload: AMQP.Spec.Basic.Deliver(
                        consumerTag: "somerandomtag",
                        deliveryTag: 1,
                        redelivered: false,
                        exchange: "swift-amqp-exchange",
                        routingKey: "swift-amqp-queue"
                    )
                )
            ),
            .inbound(
                ContentHeaderFrame(
                    channelId: expectedChannelId,
                    classId: 60,
                    bodySize: 4,
                    properties: AMQP.Spec.BasicProperties()
                )
            ),
            // assuming server delivers a frame larger than agreed 3 bytes
            .inbound(
                ContentBodyFrame(channelId: expectedChannelId, fragment: [112, 105, 110, 103])
            ),
        ]
        let env = makeTestEnv(
            with: actions,
            customizingNegotiatedProperties: {
                var (config, props) = $0
                config.maxFrameSize = 3
                return (config, props)
            }
        )
        let connection = try await Connection(with: .default, env: env)
        let channel = try await connection.makeChannel()

        #expect(connection.isOpen)
        try await channel.exchangeDeclare(named: "swift-amqp-exchange")
        _ = try await channel.queueDeclare(named: "swift-amqp-queue")
        try await channel.queueBind(queue: "swift-amqp-queue", exchange: "swift-amqp-exchange")
        let messages = try await channel.basicConsume(
            queue: "swift-amqp-queue",
            tag: "somerandomtag"
        )
        try await #require(
            throws: ConnectionError.frameSizeLimitExceeded(maxFrameSize: 3, actualSize: 12)
        ) {
            for try await message in messages {
                _ = message
                break  // safeguard to not loop forever
            }
        }
        #expect(!connection.isOpen)
    }
}
