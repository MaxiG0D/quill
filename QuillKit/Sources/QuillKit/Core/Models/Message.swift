import Foundation

struct Message: Identifiable, Hashable, Sendable {
    let id: String
    var sender: Contact
    var to: [Contact]
    var cc: [Contact]
    var date: Date
    var body: String
    /// Earlier text the sender quoted, hidden behind the quoted-text toggle.
    var quoted: String?
    var attachments: [Attachment]

    init(
        id: String = UUID().uuidString,
        sender: Contact,
        to: [Contact] = [],
        cc: [Contact] = [],
        date: Date,
        body: String,
        quoted: String? = nil,
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.sender = sender
        self.to = to
        self.cc = cc
        self.date = date
        self.body = body
        self.quoted = quoted
        self.attachments = attachments
    }

    /// The body on one line, for list previews.
    var preview: String {
        body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
