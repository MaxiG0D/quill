import Foundation

/// Decodes the `=?charset?B?…?=` form that mail headers use for text outside ASCII (RFC 2047).
enum EncodedWord {
    static func decode(_ text: String) -> String {
        guard text.contains("=?") else { return text }
        let pattern = #/=\?([^?\s]+)\?([bBqQ])\?([^?\s]*)\?=/#
        // White space between two encoded words is not part of the text.
        let joined = text.replacing(#/\?=\s+=\?/#, with: "?==?")

        var output = ""
        var cursor = joined.startIndex
        var pendingCharset: String?
        var pendingBytes = Data()
        var pendingRaw = ""

        func flushPending() {
            guard let charsetName = pendingCharset else { return }
            let charset = encoding(named: charsetName)
            output += String(data: pendingBytes, encoding: charset) ?? pendingRaw
            pendingCharset = nil
            pendingBytes.removeAll(keepingCapacity: true)
            pendingRaw = ""
        }

        for match in joined.matches(of: pattern) {
            if match.range.lowerBound > cursor {
                flushPending()
                output += joined[cursor..<match.range.lowerBound]
            }
            let charsetName = String(match.1).lowercased()
            let data =
                match.2.lowercased() == "b"
                ? Data(base64Encoded: String(match.3))
                : quotedPrintable(String(match.3))
            if let data {
                if let current = pendingCharset, current != charsetName {
                    flushPending()
                }
                pendingCharset = charsetName
                pendingBytes.append(data)
                pendingRaw += String(match.0)
            } else {
                flushPending()
                output += String(match.0)
            }
            cursor = match.range.upperBound
        }
        flushPending()
        if cursor < joined.endIndex {
            output += joined[cursor...]
        }
        return output
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
