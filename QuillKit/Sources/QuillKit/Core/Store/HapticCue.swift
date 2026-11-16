import Foundation

/// A moment worth a haptic. The store raises these and the root view plays them.
struct HapticCue: Equatable, Sendable {
    enum Kind: Sendable {
        case selection, lift, success, warning
    }

    let id = UUID()
    let kind: Kind
}
