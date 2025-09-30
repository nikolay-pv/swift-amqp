import Testing

@testable import AMQP

@Suite struct MakingObjects {

    @Test("Make Connection")
    func connection() async throws {
        let actions: [TransportMock.Action] = .init()
        let env = makeTestEnv(with: actions)
        let connection = try? await Connection(with: .default, env: env)
        #expect(connection != nil)
    }

    @Test("Make Channel")
    func channel() async throws {
        // assume the channel id is growing uniformly starting from 1
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
        ]
        let env = makeTestEnv(with: actions)
        let connection = try? await Connection(with: .default, env: env)
        #expect(connection != nil)
        let channel = try await connection?.makeChannel()
        #expect(channel != nil)
        #expect(await channel!.id == expectedChannelId)
    }
}
