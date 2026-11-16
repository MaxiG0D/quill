import Foundation

/// Writes a draft out as an RFC 5322 message for Gmail to send.
enum OutgoingMail {
    static func data(for draft: Draft, from account: Contact, replyingTo anchor: ReplyAnchor? = nil) -> Data {
        var headers = [
            "From: \(address(account))",
            "To: \(draft.to.map(address).joined(separator: ", "))",
        ]
        if !draft.cc.isEmpty {
            headers.append("Cc: \(draft.cc.map(address).joined(separator: ", "))")
        }
        headers.append("Subject: \(encoded(draft.subject))")
        if let messageID = anchor?.messageID {
            headers.append("In-Reply-To: \(messageID)")
            headers.append("References: \([anchor?.references, messageID].compactMap(\.self).joined(separator: " "))")
        }
        headers += [
            "MIME-Version: 1.0",
            "Content-Type: text/plain; charset=UTF-8",
            "Content-Transfer-Encoding: base64",
        ]

        let body = Data(text(of: draft).utf8)
            .base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])
        return Data((headers.joined(separator: "\r\n") + "\r\n\r\n" + body + "\r\n").utf8)
    }

    /// The draft's text with any quoted mail set beneath it, each line marked.
    static func text(of draft: Draft) -> String {
        guard let quoted = draft.quoted, !quoted.isEmpty else { return draft.body }
        let marked = quoted.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? ">" : "> \($0)" }
            .joined(separator: "\n")
        return draft.body + "\n\n" + marked
    }

    private static func address(_ contact: Contact) -> String {
        guard !contact.name.isEmpty else { return contact.email }
        let name =
            contact.name.allSatisfy(\.isASCII)
            ? "\"\(contact.name.replacing("\\", with: "\\\\").replacing("\"", with: "\\\""))\""
            : encoded(contact.name)
        return "\(name) <\(contact.email)>"
    }

    /// Header text outside ASCII, wrapped as an RFC 2047 encoded word.
    private static func encoded(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard !line.allSatisfy(\.isASCII) else { return line }
        return "=?UTF-8?B?\(Data(line.utf8).base64EncodedString())?="
    }
}
