import Testing

@testable import AMQP

func makeTestEnv(with actions: [TransportPostNegotiationMock.Action]) -> Environment {
    var env = Environment.shared
    env.setTransportFactory {
        var transportStub = try await TransportPostNegotiationMock(
            host: $0,
            port: $1,
            inboundContinuation: $2,
            outboundFrames: $3,
            negotiatorFactory: $4
        )
        transportStub.expecting(sequenceOf: actions)
        return transportStub
    }
    return env
}

@Suite struct ConnectionConstruction {

    @Test("Create Connection with a stub")
    func testConnectionCreation() async throws {
        let actions: [TransportPostNegotiationMock.Action] = .init()
        let env = makeTestEnv(with: actions)
        let connection = try? await Connection(with: .default, env: env)
        #expect(connection != nil)
    }

    @Test("Connection Channel creation")
    func testConnectionChannelCreation() async throws {
        // assume the channel id is growing uniformly starting from 1
        let expectedChannelId: UInt16 = 1
        let actions: [TransportPostNegotiationMock.Action] = [
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
