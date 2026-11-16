import Foundation

/// Finds where the words of a search query appear in a piece of text.
enum TextMatcher {
    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    static func terms(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Every range in `text` that matches one of the query's words, in order, without overlaps.
    static func ranges(of query: String, in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        for term in terms(in: query) {
            var start = text.startIndex
            while start < text.endIndex,
                  let range = text.range(of: term, options: options, range: start..<text.endIndex) {
                found.append(range)
                start = range.upperBound
            }
        }
        found.sort { $0.lowerBound < $1.lowerBound }

        var merged: [Range<String.Index>] = []
        for range in found {
            if let last = merged.last, range.lowerBound < last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    /// True when every word of the query appears somewhere in `text`.
    static func matches(_ query: String, in text: String) -> Bool {
        let terms = terms(in: query)
        return !terms.isEmpty && terms.allSatisfy { text.range(of: $0, options: options) != nil }
    }

    /// A one-line excerpt that keeps the first match in view.
    static func excerpt(of text: String, around query: String, lead: Int = 28) -> String {
        guard let first = ranges(of: query, in: text).first else { return text }
        let offset = text.distance(from: text.startIndex, to: first.lowerBound)
        guard offset > lead else { return text }

        var start = text.index(first.lowerBound, offsetBy: -lead)
        // Back up to a word boundary so the excerpt does not open mid-word.
        while start > text.startIndex, !text[text.index(before: start)].isWhitespace {
            start = text.index(before: start)
        }
        return start == text.startIndex ? text : "…" + text[start...]
    }
}
