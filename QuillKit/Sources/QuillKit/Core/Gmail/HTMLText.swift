import Foundation

/// Turns an HTML message into plain text for reading, for mail that carries no text version.
enum HTMLText {
    static func plain(from html: String) -> String {
        var text = html.replacing("\r\n", with: "\n")
        text.replace(#/(?is)<!--.*?-->/#, with: "")
        text.replace(#/(?is)<(head|style|script|title)\b.*?</\1\s*>/#, with: "")
        text.replace(#/[\r\n\t]+/#, with: " ")
        text.replace(#/(?i)<br\s*/?>/#, with: "\n")
        text.replace(#/(?i)<li\b[^>]*>/#, with: "\n• ")
        text.replace(#/(?i)</(p|div|tr|h[1-6]|ul|ol|table|blockquote)\s*>/#, with: "\n\n")
        text.replace(#/(?s)<[^>]*>/#, with: "")
        text = decodingEntities(in: text)

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.replacing(#/[ \u{00A0}]+/#, with: " ").trimmingCharacters(in: .whitespaces)
        }
        // Keep one empty line between paragraphs.
        var kept: [String] = []
        for line in lines where !(line.isEmpty && (kept.last?.isEmpty ?? true)) {
            kept.append(line)
        }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "mdash": "—", "ndash": "–",
        "hellip": "…", "copy": "©", "reg": "®", "trade": "™", "bull": "•", "middot": "·",
        "zwnj": "", "zwj": "", "shy": "",
    ]

    private static func decodingEntities(in text: String) -> String {
        guard text.contains("&") else { return text }
        return text.replacing(#/&(#[xX]?[0-9a-fA-F]+|[a-zA-Z]+);/#) { match -> String in
            let name = match.1
            if name.hasPrefix("#") {
                let digits = name.dropFirst()
                let isHex = digits.hasPrefix("x") || digits.hasPrefix("X")
                let value = isHex ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits, radix: 10)
                return value.flatMap { Unicode.Scalar($0) }.map { String(Character($0)) } ?? String(match.0)
            }
            return named[String(name)] ?? String(match.0)
        }
    }
}
