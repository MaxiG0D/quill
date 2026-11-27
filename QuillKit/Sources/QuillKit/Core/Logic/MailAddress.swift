import Foundation

/// A street address found in a message, in French or English: "500 Rue d'Avaugour, Boucherville, J4B 0G6",
/// "120 Main St, Springfield, IL 62701". Footers, signatures and shipping or billing addresses are left out,
/// so a card only shows for a place the message is about.
struct MailAddress: Hashable, Sendable {
    /// The street line: "500 Rue d'Avaugour, Bureau 2010".
    let street: String
    /// The city, region and postal code, empty when the message gives only the street.
    let locality: String

    var full: String { locality.isEmpty ? street : "\(street), \(locality)" }

    /// The first address in `text` that is not in a footer, a signature or a shipping or billing block.
    static func find(in text: String) -> MailAddress? {
        let lines = body(of: text)
        return postalBlock(in: lines)
            ?? detected(in: lines.joined(separator: "\n"))
            ?? loneStreet(in: lines)
    }

    /// True when the text introduces the address as a place to go: "Adresse :", "Where:", "Join us at".
    /// Company addresses in letterheads and sign-offs have no such lead-in.
    static func isAnnounced(_ address: MailAddress, in text: String) -> Bool {
        let folded = fold(String(text.prefix(20_000)))
        guard let range = folded.range(of: fold(address.street)) else { return false }
        let lead = folded[folded.index(range.lowerBound, offsetBy: -120, limitedBy: folded.startIndex) ?? folded.startIndex..<range.lowerBound]
        // Only the last line or two before the street count, so a cue elsewhere in the message does not.
        let nearby = lead.split(separator: "\n", omittingEmptySubsequences: true).suffix(2).joined(separator: "\n")
        return placeCue.firstMatch(in: nearby, range: NSRange(nearby.startIndex..., in: nearby)) != nil
    }

    private static let placeCue = regex(
        #"(?:^|\n)\s*(?:adresse|address|lieu|location|emplacement|venue|where|ou|point de rencontre|meeting point)\s*:|\b(?:located at|situee? au|situee? a|nous trouver|find us at|join us at|see you at|meet (?:us |me )?at|rendez-vous (?:au|a|chez)|pick ?up (?:at|from)|cueillette au|takes place at|se tiendra au|aura lieu au|held at)\b"#
    )

    // MARK: Where to look

    /// The message without its signature and without the footer bulk mail ends with.
    private static func body(of text: String) -> [String] {
        var lines = String(text.prefix(20_000))
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if let signature = lines.firstIndex(where: { $0 == "--" || $0 == "—" }) {
            lines = Array(lines[..<signature])
        }
        if let footer = lines.indices.dropFirst().first(where: { matches(footerCue, lines[$0]) }) {
            lines = Array(lines[..<footer])
        }
        return lines
    }

    private static let footerCue = regex(
        #"unsubscribe|desabonn|desinscri|©|\bcopyright\b|all rights reserved|tous droits reserves|privacy policy|politique de confidentialite|you (?:are )?receiv\w* this|vous (?:avez )?recu ce|vous recevez ce|manage (?:your )?(?:email )?preferences|gerer vos preferences"#
    )

    /// "Ship to", "Adresse de facturation": the reader's own address, not a place to go.
    private static let accountCue = regex(
        #"\b(?:ship(?:ping|ped)?|deliver(?:y|ed)?|bill(?:ing)?|mailing|livraison|livre|facturation|expedi\w*)\b"#
    )

    /// A street name: a number, then a word for the kind of street.
    private static let streetLine = regex(
        #"^\d+[A-Za-z]?(?:-\d+)?,?\s+.*\b(?:rue|av|ave|avenue|boul|boulevard|blvd|bd|ch|chemin|route|rte|rang|mont[ée]e|c[ôo]te|all[ée]e|impasse|place|pl|square|sq|promenade|street|st|road|rd|drive|dr|lane|ln|way|court|ct|crescent|cres|circle|cir|parkway|pkwy|highway|hwy|terrace|ter|trail|plaza|broadway)\b"#
    )

    // MARK: Postal block

    /// Canadian postal code, US state and ZIP, or a French postcode opening its line.
    private static let postal = regex(
        #"\b[A-Z]\d[A-Z][ -]?\d[A-Z]\d\b|\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b|^\d{5}\s+\p{L}"#,
        options: [.caseInsensitive, .anchorsMatchLines]
    )
    private static let country = regex(#"^(?:canada|usa|united states|etats-unis|france)$"#)

    /// The lines from a street line down to a postal code, at most three lines apart.
    private static func postalBlock(in lines: [String]) -> MailAddress? {
        for (index, line) in lines.enumerated() where line.count <= 120 && matches(postal, line) {
            var cursor = index
            var first: Int?
            while cursor >= 0, index - cursor <= 3 {
                let candidate = lines[cursor]
                if candidate.isEmpty || candidate.count > 120 { break }
                if matches(streetLine, candidate) {
                    first = cursor
                    break
                }
                cursor -= 1
            }
            guard let first, !isAccountAddress(lines, above: first) else { continue }
            var parts = Array(lines[first...index])
            if index + 1 < lines.count, matches(country, lines[index + 1]) {
                parts.append(lines[index + 1])
            }
            return split(parts)
        }
        return nil
    }

    /// The street line itself or the two lines above it name a shipping or billing address.
    private static func isAccountAddress(_ lines: [String], above index: Int) -> Bool {
        lines[max(0, index - 2)...index].contains { matches(accountCue, $0) }
    }

    /// One block as street and locality: the first line is the street, unless it holds everything,
    /// as in "120 Main St, Springfield, IL 62701".
    private static func split(_ parts: [String]) -> MailAddress {
        let joined = parts.joined(separator: ", ")
        if parts.count == 1, let comma = joined.firstIndex(of: ",") {
            return MailAddress(
                street: String(joined[..<comma]),
                locality: joined[joined.index(after: comma)...].trimmingCharacters(in: .whitespaces)
            )
        }
        return MailAddress(street: parts[0], locality: parts.dropFirst().joined(separator: ", "))
    }

    // MARK: Lone street

    /// A line that is only a street, as clinics often sign off: "1251 Chemin du Tremblay".
    /// Maps places it near the reader, and no card shows when it cannot.
    private static func loneStreet(in lines: [String]) -> MailAddress? {
        for (index, line) in lines.enumerated()
        where line.count <= 60
            && line.split(separator: " ").count <= 8
            && !line.contains(where: { ".!?:;".contains($0) })
            && matches(streetLine, line)
            && !isAccountAddress(lines, above: index) {
            return split([line])
        }
        return nil
    }

    // MARK: Detected

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)

    /// An address the system finds, kept only when it has a numbered street and a city or postal code.
    private static func detected(in text: String) -> MailAddress? {
        guard let detector else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let components = match.addressComponents,
                  let street = components[.street]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  matches(streetLine, street)
            else { continue }
            let city = components[.city]
            let zip = components[.zip]
            guard city != nil || zip != nil else { continue }
            let start = text.index(text.startIndex, offsetBy: max(0, match.range.location - 80), limitedBy: text.endIndex) ?? text.startIndex
            let end = Range(match.range, in: text)?.lowerBound ?? text.endIndex
            if start < end, matches(accountCue, String(text[start..<end])) { continue }
            let region = [components[.state], zip].compactMap(\.self).joined(separator: " ")
            let locality = [city, region.isEmpty ? nil : region].compactMap(\.self).joined(separator: ", ")
            return MailAddress(street: street, locality: locality)
        }
        return nil
    }

    // MARK: Matching

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Matches ignore case and accents, so "Désabonner" and "desabonner" read the same.
    private static func matches(_ expression: NSRegularExpression, _ text: String) -> Bool {
        let folded = fold(text)
        return expression.firstMatch(in: folded, range: NSRange(folded.startIndex..., in: folded)) != nil
    }

    private static func regex(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> NSRegularExpression {
        // The patterns are constants, checked by the tests.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: options)
    }
}

/// Addresses found per message, so a message is read once.
@MainActor
enum MailAddressCache {
    private static var found: [String: MailAddress?] = [:]

    static func address(in message: Message) -> MailAddress? {
        let source = message.body.isEmpty ? message.snippet ?? "" : message.body
        let key = "\(message.id):\(source.count)"
        if let cached = found[key] { return cached }
        let address = MailAddress.find(in: source)
        if found.count > 2000 { found.removeAll() }
        found[key] = address
        return address
    }

    private static var cards: [String: Bool] = [:]

    /// The address worth a map card: one the message is about, because it holds an event
    /// or introduces the address as a place to go. Letterheads and company sign-offs get none.
    static func cardAddress(in message: Message, subject: String) -> MailAddress? {
        guard let address = address(in: message) else { return nil }
        let source = message.body.isEmpty ? message.snippet ?? "" : message.body
        let key = "\(message.id):\(source.count)"
        if let shows = cards[key] { return shows ? address : nil }
        let shows = MailEventCache.event(in: message, subject: subject) != nil
            || MailAddress.isAnnounced(address, in: source)
        if cards.count > 2000 { cards.removeAll() }
        cards[key] = shows
        return shows ? address : nil
    }
}
