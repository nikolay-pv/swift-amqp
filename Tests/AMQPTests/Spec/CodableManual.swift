import Foundation
import Testing

@testable import AMQP

@Suite struct BoolPackCoding {
    @Test(
        "Sequential Bool members are packed into one byte",
        arguments: zip(
            [
                Spec.Basic.Consume(noLocal: true, noAck: true, exclusive: true, nowait: true),
                Spec.Basic.Consume(noLocal: true, noAck: false, exclusive: true, nowait: true),
                Spec.Basic.Consume(noLocal: false, noAck: true, exclusive: false, nowait: true),
            ],
            [0b1111, 0b1101, 0b1010]
        )
    )
    func encodeSequenceOfBools(method: Spec.Basic.Consume, expectedByte: UInt8) async throws {
        let encoded = try FrameEncoder().encode(method)
        var expected = [UInt8].init(repeating: UInt8.zero, count: 9)
        expected[4] = expectedByte
        #expect(encoded == Data(expected))
    }
}

@Suite struct AMQPFrameCoding {
    @Test("ProtocolHeaderFrame default encoding/decoding roundtrip")
    func protocolHeaderFrame() async throws {
        let object = ProtocolHeaderFrame(majorVersion: 0, minorVersion: 9, revision: 1)
        let binary = try FrameEncoder().encode(object)
        let decoded = try FrameDecoder().decode(ProtocolHeaderFrame.self, from: binary)
        #expect(binary.count == object.bytesCount)
        #expect(decoded == object)
    }

    @Test("MethodFrame default encoding/decoding roundtrip")
    func methodFrame() async throws {
        let method = Spec.Basic.Ack()
        // MethodFrame doesn't conform to Equatable due to non conformant FrameCodable
        let object = MethodFrame(channelId: 3, payload: method)
        let binary = try FrameEncoder().encode(object)
        let decoded = try FrameDecoder().decode(MethodFrame.self, from: binary)
        #expect(binary.count == object.bytesCount)
        #expect(decoded.channelId == object.channelId)
        let decodedMethod = decoded.payload as? Spec.Basic.Ack
        #expect(decodedMethod != nil)
        #expect(decodedMethod! == method)
    }

    @Test("HeartbeatFrame default encoding/decoding roundtrip")
    func heartbeatFrame() async throws {
        let object = HeartbeatFrame()
        let binary = try FrameEncoder().encode(object)
        let decoded = try FrameDecoder().decode(HeartbeatFrame.self, from: binary)
        #expect(binary.count == object.bytesCount)
        #expect(decoded == object)
    }

    @Test("ContentHeaderFrame default encoding/decoding roundtrip")
    func contentHeaderFrame() async throws {
        let object = ContentHeaderFrame(
            channelId: 3,
            classId: Spec.Basic.Publish().amqpClassId,
            bodySize: 10,
            properties: .init()
        )
        let binary = try FrameEncoder().encode(object)
        let decoded = try FrameDecoder().decode(ContentHeaderFrame.self, from: binary)
        #expect(binary.count == object.bytesCount)
        #expect(decoded == object)
    }

    @Test("ContentBodyFrame default encoding/decoding roundtrip")
    func contentBodyFrame() async throws {
        let object = ContentBodyFrame(channelId: 3, fragment: [0, 1, 2, 3, 4, 5])
        let binary = try FrameEncoder().encode(object)
        let decoded = try FrameDecoder().decode(ContentBodyFrame.self, from: binary)
        #expect(binary.count == object.bytesCount)
        #expect(decoded == object)
    }
}
