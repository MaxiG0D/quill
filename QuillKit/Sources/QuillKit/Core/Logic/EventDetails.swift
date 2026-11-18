import Foundation

/// What a calendar entry carries besides its time: where it is and who to call.
struct EventDetails: Hashable, Sendable {
    var title: String
    var location: String?
    var notes: String?

    /// Reads the address and phone number from a message's text.
    static func make(title: String, sender: String, text: String) -> EventDetails {
        let phone = phone(in: text)
        var notes: [String] = []
        if !sender.isEmpty, sender != title { notes.append(sender) }
        if let phone { notes.append(phone) }
        return EventDetails(
            title: title,
            location: address(in: text),
            notes: notes.isEmpty ? nil : notes.joined(separator: "\n")
        )
    }

    private static let postal = regex(
        // Canadian postal code, US state and ZIP, or a French postcode opening its line.
        #"\b[A-Z]\d[A-Z][ -]?\d[A-Z]\d\b|\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b|^\d{5}\s+\p{L}"#,
        options: [.caseInsensitive, .anchorsMatchLines]
    )
    private static let street = regex(#"^\d+[A-Za-z]?(?:-\d+)?[,\s]+\p{L}"#)
    private static let country = regex(#"^(?:canada|usa|united states|etats-unis|france)$"#)

    /// A postal address: the lines from the street number down to the postal code, joined on one line.
    static func address(in text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        for (index, line) in lines.enumerated() where line.count <= 120 && matches(postal, line) {
            var first: Int?
            var cursor = index
            while cursor >= 0, index - cursor <= 3 {
                let candidate = lines[cursor]
                if candidate.isEmpty || candidate.count > 120 { break }
                if matches(street, candidate) {
                    first = cursor
                    break
                }
                cursor -= 1
            }
            guard let first else { continue }
            var parts = Array(lines[first...index])
            if index + 1 < lines.count, matches(country, lines[index + 1].folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)) {
                parts.append(lines[index + 1])
            }
            return parts.joined(separator: ", ")
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        guard let match = detector?.firstMatch(in: text, range: range),
              let bounds = Range(match.range, in: text) else { return nil }
        return text[bounds]
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    static func phone(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.phoneNumber
    }

    private static func matches(_ expression: NSRegularExpression, _ text: String) -> Bool {
        expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func regex(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> NSRegularExpression {
        // The patterns are constants, checked by the tests.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: options)
    }
}
