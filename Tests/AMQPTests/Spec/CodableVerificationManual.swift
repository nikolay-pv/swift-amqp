import Testing

@testable import AMQP

@Suite struct ConnectionDecodeRegression {
    @Test("Spec.Connection.StartOk verify decode bytes - extended")
    func amqpConnectionStartOkDecodeBytes() async throws {
        let input = try fixtureData(named: "Connection.StartOk-extended")
        let decoded = try FrameDecoder().decode(Spec.Connection.StartOk.self, from: input)
        let expected = Spec.Connection.StartOk(
            clientProperties: ["product": Spec.FieldValue.longstr("test")],
            mechanism: "PLAIN",
            response: "\0test\0test",
            locale: "en_US"
        )
        #expect(decoded == expected)
    }
}
