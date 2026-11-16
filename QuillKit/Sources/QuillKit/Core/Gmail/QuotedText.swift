import Foundation

/// Separates what someone wrote from the earlier mail they quoted beneath it.
enum QuotedText {
    static func split(_ text: String) -> (body: String, quoted: String?) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.indices.first(where: { startsQuote(at: $0, in: lines) }), start > 0 else {
            return (text, nil)
        }
        let body = lines[..<start].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = lines[start...]
            .map { $0.replacing(#/^\s*(>\s?)+/#, with: "") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !quoted.isEmpty else {
            return (text, nil)
        }
        return (body, quoted)
    }

    private static func startsQuote(at index: Int, in lines: [String]) -> Bool {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        if line.hasPrefix(">") || line.hasPrefix("-----Original Message-----") {
            return true
        }
        // "On Tue, Nov 11, Priya Raman wrote:", which long addresses can push onto a second line.
        guard line.hasPrefix("On ") else { return false }
        if line.hasSuffix("wrote:") {
            return true
        }
        let next = index + 1 < lines.count ? lines[index + 1].trimmingCharacters(in: .whitespaces) : ""
        return next.hasSuffix("wrote:") && !next.hasPrefix("On ")
    }
}
