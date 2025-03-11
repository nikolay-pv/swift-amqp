import Foundation
import Testing

@testable import AMQP

@Suite struct BoolPackCoding {
    @Test(
        "Sequential Bools are packed into one byte",
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
