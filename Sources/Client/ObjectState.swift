import Atomics

enum ObjectState: Int, Sendable, AtomicValue {
    case opening
    case open
    case closing
    case closed
}
