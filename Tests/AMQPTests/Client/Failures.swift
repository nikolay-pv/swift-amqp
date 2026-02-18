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
        let connection = try await Connection(with: .default, env: env)
        let channel = try await connection.makeChannel()
        try await connection.close()
        try await #require(
            throws: ConnectionError.connectionIsClosed
        ) {
            let _ = try await channel.queueDeclare(named: "test")
        }
        #expect(!connection.isOpen)
        #expect(!channel.isOpen)
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
            throws: ChannelError.channelIsClosed("")
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
        try await connection.close()
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
        let channel = try await connection.makeChannel()
        // the connection should remain open
        #expect(channel.isOpen)
        #expect(connection.isOpen)
        try await connection.close()
        #expect(!channel.isOpen)
    }
}
