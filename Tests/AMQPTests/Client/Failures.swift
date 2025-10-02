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
}
