import Foundation

struct Message: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var sender: Contact
    var to: [Contact]
    var cc: [Contact]
    var date: Date
    var body: String
    /// Earlier text the sender quoted, hidden behind the quoted-text toggle.
    var quoted: String?
    var attachments: [Attachment]
    /// The message as its sender designed it, kept only for mail that depends on its layout.
    var html: String?
    /// The mail service's own one-line summary, when it gives one.
    var snippet: String?
    /// How to stop mail from the list this message came from, when it says.
    var unsubscribe: Unsubscribe?

    init(
        id: String = UUID().uuidString,
        sender: Contact,
        to: [Contact] = [],
        cc: [Contact] = [],
        date: Date,
        body: String,
        quoted: String? = nil,
        attachments: [Attachment] = [],
        html: String? = nil,
        snippet: String? = nil,
        unsubscribe: Unsubscribe? = nil
    ) {
        self.id = id
        self.sender = sender
        self.to = to
        self.cc = cc
        self.date = date
        self.body = body
        self.quoted = quoted
        self.attachments = attachments
        self.html = html
        self.snippet = snippet
        self.unsubscribe = unsubscribe
    }

    /// One line for list previews. Designed mail uses the service's summary, since its text is
    /// mostly layout; other mail uses the body, with an opening greeting such as "Hi both," left out.
    var preview: String {
        if html != nil, let snippet, !snippet.isEmpty {
            return snippet
        }
        var lines = body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if lines.count > 1, let first = lines.first, first.hasSuffix(","), first.split(separator: " ").count <= 4 {
            lines.removeFirst()
        }
        return lines.joined(separator: " ")
    }
}
