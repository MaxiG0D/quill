import SwiftUI

/// Text with the words of a search query marked in the accent tint.
struct HighlightedText: View {
    let text: String
    let query: String

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        for range in TextMatcher.ranges(of: query, in: text) {
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result)
            else { continue }
            result[lower..<upper].swiftUI.backgroundColor = Palette.accentTint
            result[lower..<upper].swiftUI.foregroundColor = Palette.accent
        }
        return result
    }
}
