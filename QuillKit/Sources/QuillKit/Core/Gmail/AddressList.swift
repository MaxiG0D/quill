import Foundation

/// Reads the people out of a From, To or Cc header.
enum AddressList {
    static func contacts(in header: String?) -> [Contact] {
        guard let header else { return [] }
        return split(unwrappingGroups(in: header)).compactMap(contact)
    }

    /// Strips RFC 5322 group labels (`Team: a@b.com, c@d.com;`) outside quotes and angle brackets.
    private static func unwrappingGroups(in header: String) -> String {
        var result = ""
        var isQuoted = false
        var isEscaped = false
        var angleDepth = 0
        var segmentStart = result.endIndex
        for character in header {
            if isEscaped {
                isEscaped = false
                result.append(character)
                continue
            }
            if character == "\\" {
                isEscaped = true
                result.append(character)
                continue
            }
            if character == "\"" {
                isQuoted.toggle()
                result.append(character)
                continue
            }
            if !isQuoted {
                if character == "<" {
                    angleDepth += 1
                } else if character == ">" {
                    angleDepth = max(angleDepth - 1, 0)
                } else if character == ":", angleDepth == 0 {
                    // Drop the group display name prefix before `:`.
                    result.removeSubrange(segmentStart..<result.endIndex)
                    continue
                } else if character == ";", angleDepth == 0 {
                    result.append(",")
                    segmentStart = result.endIndex
                    continue
                } else if character == ",", angleDepth == 0 {
                    result.append(character)
                    segmentStart = result.endIndex
                    continue
                }
            }
            result.append(character)
        }
        return result
    }

    /// Removes RFC 5322 parenthesized comments (`alice@example.com (Alice)`) outside quotes.
    private static func stripComments(from text: String) -> (cleaned: String, comment: String) {
        var cleaned = ""
        var comment = ""
        var isQuoted = false
        var isEscaped = false
        var commentDepth = 0
        for character in text {
            if isEscaped {
                isEscaped = false
                if commentDepth > 0 { comment.append(character) } else { cleaned.append(character) }
                continue
            }
            if character == "\\" {
                isEscaped = true
                if commentDepth > 0 { comment.append(character) } else { cleaned.append(character) }
                continue
            }
            if character == "\"", commentDepth == 0 {
                isQuoted.toggle()
                cleaned.append(character)
                continue
            }
            if !isQuoted {
                if character == "(" {
                    commentDepth += 1
                    continue
                } else if character == ")", commentDepth > 0 {
                    commentDepth -= 1
                    continue
                }
            }
            if commentDepth > 0 {
                comment.append(character)
            } else {
                cleaned.append(character)
            }
        }
        return (cleaned.trimmingCharacters(in: .whitespacesAndNewlines), comment.trimmingCharacters(in: .whitespacesAndNewlines))
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

    private static func contact(from rawEntry: String) -> Contact? {
        let stripped = stripComments(from: rawEntry)
        let entry = stripped.cleaned
        guard !entry.isEmpty else { return nil }
        guard let open = entry.lastIndex(of: "<"), let close = entry.lastIndex(of: ">"), open < close else {
            return entry.contains("@") ? Contact(name: EncodedWord.decode(stripped.comment), email: entry.lowercased()) : nil
        }

        let email = entry[entry.index(after: open)..<close].trimmingCharacters(in: .whitespaces).lowercased()
        var name = entry[..<open].trimmingCharacters(in: .whitespaces)
        if name.count >= 2, name.hasPrefix("\""), name.hasSuffix("\"") {
            name = String(name.dropFirst().dropLast())
        }
        name = name.replacing("\\\"", with: "\"").replacing("\\\\", with: "\\")
        if name.isEmpty { name = stripped.comment }
        guard !email.isEmpty else { return nil }
        return Contact(name: EncodedWord.decode(name), email: email)
    }
}
