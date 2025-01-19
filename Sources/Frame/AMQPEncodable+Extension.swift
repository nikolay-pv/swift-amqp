import Foundation

extension AMQPEncodable {
    // Convert the encodable object to an AMQP frame data.
    func asFrame() throws -> Data {
        let encoder = FrameEncoder()
        return try encoder.encode(self)
    }
}
