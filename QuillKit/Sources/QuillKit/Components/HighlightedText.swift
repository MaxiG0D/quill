import SwiftUI

/// Text with the words of a search query marked in the accent tint.
struct HighlightedText: View {
    let text: String
    let query: String
    /// True when sitting on `Palette.accentTint`, so the highlight stays visible.
    var onTint = false

    var body: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(text)
        } else {
            Text(attributed)
        }
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        let highlightBackground = onTint ? Palette.surface : Palette.accentTint
        for range in TextMatcher.ranges(of: query, in: text) {
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result)
            else { continue }
            result[lower..<upper].swiftUI.backgroundColor = highlightBackground
            result[lower..<upper].swiftUI.foregroundColor = Palette.accent
        }
        return result
    }
}
