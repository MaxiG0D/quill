import SwiftUI

/// The animation curves used across the app, so motion feels like one hand made it.
enum Motion {
    /// Rows leaving and arriving, selection changes.
    static let list = Animation.snappy(duration: 0.32)
    /// Cards opening and closing.
    static let expand = Animation.spring(duration: 0.38, bounce: 0.16)
    /// Small state flips such as a star or a chip.
    static let quick = Animation.snappy(duration: 0.2)
    /// Larger scene changes such as entering search.
    static let scene = Animation.smooth(duration: 0.36)
}
