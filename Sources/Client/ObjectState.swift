import Atomics

enum ObjectState: Int, Sendable, AtomicValue {
    case open
    case closing
    case closed
}
