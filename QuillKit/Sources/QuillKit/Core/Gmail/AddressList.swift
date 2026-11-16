import Foundation

/// Reads the people out of a From, To or Cc header.
enum AddressList {
    static func contacts(in header: String?) -> [Contact] {
        guard let header else { return [] }
        return split(header).compactMap(contact)
    }

    /// Splits on the commas between addresses, leaving those inside quotes or angle brackets alone.
    private static func split(_ header: String) -> [String] {
        var entries: [String] = []
        var current = ""
        var isQuoted = false
        var isEscaped = false
        var depth = 0
        for character in header {
            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                isQuoted.toggle()
            } else if !isQuoted {
                if character == "<" {
                    depth += 1
                } else if character == ">" {
                    depth = max(depth - 1, 0)
                } else if character == ",", depth == 0 {
                    entries.append(current)
                    current = ""
                    continue
                }
            }
            current.append(character)
        }
        entries.append(current)
        return entries
    }

    private static func contact(from entry: String) -> Contact? {
        let entry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.isEmpty else { return nil }
        guard let open = entry.lastIndex(of: "<"), let close = entry.lastIndex(of: ">"), open < close else {
            return entry.contains("@") ? Contact(name: "", email: entry.lowercased()) : nil
        }

        let email = entry[entry.index(after: open)..<close].trimmingCharacters(in: .whitespaces).lowercased()
        var name = entry[..<open].trimmingCharacters(in: .whitespaces)
        if name.count >= 2, name.hasPrefix("\""), name.hasSuffix("\"") {
            name = String(name.dropFirst().dropLast())
        }
        name = name.replacing("\\\"", with: "\"").replacing("\\\\", with: "\\")
        guard !email.isEmpty else { return nil }
        return Contact(name: EncodedWord.decode(name), email: email)
    }
}
