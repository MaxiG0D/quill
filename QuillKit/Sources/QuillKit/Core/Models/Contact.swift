import Foundation

struct Contact: Identifiable, Hashable, Codable, Sendable {
    var name: String
    var email: String
    var tone: LabelTone

    var id: String { email }

    init(name: String, email: String, tone: LabelTone? = nil) {
        self.name = name
        self.email = email
        self.tone = tone ?? .stable(for: email)
    }

    /// Up to two leading letters, one per word: "Priya Raman" is "PR", "Max" is "M".
    var initials: String {
        let words = displayName.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }

    /// The name, or the address when the sender has no name.
    var displayName: String {
        name.isEmpty ? email : name
    }

    /// The first word of the name, used where space is tight.
    var shortName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }
}
