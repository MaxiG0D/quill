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
        text.replace(#/(?i)</(td|th)\s*>/#, with: " ")
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
        "euro": "€", "pound": "£", "yen": "¥", "cent": "¢", "laquo": "«", "raquo": "»",
        "deg": "°", "times": "×", "divide": "÷", "plusmn": "±",
        "eacute": "é", "egrave": "è", "ecirc": "ê", "euml": "ë",
        "aacute": "á", "agrave": "à", "acirc": "â", "auml": "ä", "aring": "å", "aelig": "æ",
        "iacute": "í", "igrave": "ì", "icirc": "î", "iuml": "ï",
        "oacute": "ó", "ograve": "ò", "ocirc": "ô", "ouml": "ö", "oslash": "ø", "oelig": "œ",
        "uacute": "ú", "ugrave": "ù", "ucirc": "û", "uuml": "ü",
        "ccedil": "ç", "ntilde": "ñ", "szlig": "ß",
        "Eacute": "É", "Egrave": "È", "Ecirc": "Ê", "Agrave": "À", "Acirc": "Â", "Ccedil": "Ç",
        "Ocirc": "Ô", "OElig": "Œ", "Ugrave": "Ù", "Ucirc": "Û", "Ntilde": "Ñ",
        "zwnj": "", "zwj": "", "shy": "",
    ]

    /// Maps numeric references in the Windows-1252 C1 range (128–159) to their Unicode glyphs.
    private static let windows1252: [UInt32: String] = [
        0x80: "€", 0x82: "‚", 0x83: "ƒ", 0x84: "„", 0x85: "…", 0x86: "†", 0x87: "‡",
        0x88: "ˆ", 0x89: "‰", 0x8A: "Š", 0x8B: "‹", 0x8C: "Œ", 0x8E: "Ž",
        0x91: "‘", 0x92: "’", 0x93: "“", 0x94: "”", 0x95: "•", 0x96: "–", 0x97: "—",
        0x98: "˜", 0x99: "™", 0x9A: "š", 0x9B: "›", 0x9C: "œ", 0x9E: "ž", 0x9F: "Ÿ",
    ]

    /// Replaces entities such as `&amp;` and `&#39;` with the characters they stand for.
    static func decodingEntities(in text: String) -> String {
        guard text.contains("&") else { return text }
        return text.replacing(#/&(#[xX]?[0-9a-fA-F]+|[a-zA-Z]+);/#) { match -> String in
            let name = match.1
            if name.hasPrefix("#") {
                let digits = name.dropFirst()
                let isHex = digits.hasPrefix("x") || digits.hasPrefix("X")
                guard let value = isHex ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits, radix: 10) else {
                    return String(match.0)
                }
                if let mapped = windows1252[value] {
                    return mapped
                }
                return Unicode.Scalar(value).map { String(Character($0)) } ?? String(match.0)
            }
            return named[String(name)] ?? named[String(name).lowercased()] ?? String(match.0)
        }
    }
}
