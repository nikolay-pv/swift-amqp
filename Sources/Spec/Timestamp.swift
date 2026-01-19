//   NOTE: This -*- swift -*- source code is implemented manually
//

public struct Timestamp: Sendable {
    let millisecondsSince1970: UInt64

    init(millisecondsSince1970 value: UInt64) {
        self.millisecondsSince1970 = value
    }

    static let distantPast: Timestamp = .init(millisecondsSince1970: 0)
    var bytesCount: UInt16 { 8 }
}

extension Timestamp: Equatable {}
extension Timestamp: Hashable {}
