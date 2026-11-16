/// Sizes that differ between touch and pointer platforms.
enum Metrics {
    static let hairline = 0.5

    /// The smallest comfortable hit target.
    #if os(macOS)
    static let target = 30.0
    #else
    static let target = 44.0
    #endif

    /// The margin around the open message in the wide layout.
    #if os(macOS)
    static let panePadding = 56.0
    #else
    static let panePadding = 32.0
    #endif

    /// The widest a column of reading text should grow.
    static let readingWidth = 720.0
}
