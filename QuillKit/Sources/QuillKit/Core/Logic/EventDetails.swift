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

    private static let phoneDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)

    /// The message's street address, on one line.
    static func address(in text: String) -> String? {
        MailAddress.find(in: text)?.full
    }

    static func phone(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        return phoneDetector?.firstMatch(in: text, range: range)?.phoneNumber
    }
}
