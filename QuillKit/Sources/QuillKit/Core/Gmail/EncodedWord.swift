import Foundation

/// Decodes the `=?charset?B?…?=` form that mail headers use for text outside ASCII (RFC 2047).
enum EncodedWord {
    static func decode(_ text: String) -> String {
        guard text.contains("=?") else { return text }
        let word = #/=\?([^?\s]+)\?([bBqQ])\?([^?\s]*)\?=/#
        // White space between two encoded words is not part of the text.
        let joined = text.replacing(#/\?=\s+=\?/#, with: "?==?")
        return joined.replacing(word) { match -> String in
            let charset = encoding(named: String(match.1))
            let data =
                match.2.lowercased() == "b"
                ? Data(base64Encoded: String(match.3))
                : quotedPrintable(String(match.3))
            return data.flatMap { String(data: $0, encoding: charset) } ?? String(match.0)
        }
    }

    private static func encoding(named name: String) -> String.Encoding {
        let charset = name.split(separator: "*").first.map(String.init) ?? name
        let converted = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
        guard converted != kCFStringEncodingInvalidId else { return .utf8 }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(converted))
    }

    private static func quotedPrintable(_ text: String) -> Data? {
        var bytes: [UInt8] = []
        var iterator = text.utf8.makeIterator()
        while let byte = iterator.next() {
            switch byte {
            case UInt8(ascii: "_"):
                bytes.append(UInt8(ascii: " "))
            case UInt8(ascii: "="):
                guard let high = iterator.next(), let low = iterator.next(),
                    let value = UInt8(String(decoding: [high, low], as: UTF8.self), radix: 16)
                else { return nil }
                bytes.append(value)
            default:
                bytes.append(byte)
            }
        }
        return Data(bytes)
    }
}
