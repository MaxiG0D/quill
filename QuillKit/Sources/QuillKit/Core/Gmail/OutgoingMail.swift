import Foundation

/// Writes a draft out as an RFC 5322 message for Gmail to send.
enum OutgoingMail {
    static func data(for draft: Draft, from account: Contact, replyingTo anchor: ReplyAnchor? = nil) -> Data {
        var headers = [
            "From: \(address(account))",
        ]
        if !draft.to.isEmpty {
            headers.append("To: \(draft.to.map(address).joined(separator: ", "))")
        }
        if !draft.cc.isEmpty {
            headers.append("Cc: \(draft.cc.map(address).joined(separator: ", "))")
        }
        if !draft.bcc.isEmpty {
            headers.append("Bcc: \(draft.bcc.map(address).joined(separator: ", "))")
        }
        headers.append("Subject: \(encoded(draft.subject))")
        if let messageID = anchor?.messageID {
            headers.append("In-Reply-To: \(sanitizedHeader(messageID))")
            headers.append("References: \([anchor?.references, messageID].compactMap(\.self).map(sanitizedHeader).joined(separator: " "))")
        }
        headers.append("MIME-Version: 1.0")

        let plainBase64 = Data(text(of: draft).utf8)
            .base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])

        let bodyPart: (contentType: String, payload: String)
        if let htmlBody = draft.htmlBody, !htmlBody.isEmpty {
            let altBoundary = "quill-alt-\(UUID().uuidString.replacing("-", with: ""))"
            let fullHTML = htmlDocument(body: htmlBody, quoted: draft.quoted)
            let htmlBase64 = Data(fullHTML.utf8)
                .base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])
            let payload = [
                "--\(altBoundary)",
                "Content-Type: text/plain; charset=UTF-8",
                "Content-Transfer-Encoding: base64",
                "",
                plainBase64,
                "--\(altBoundary)",
                "Content-Type: text/html; charset=UTF-8",
                "Content-Transfer-Encoding: base64",
                "",
                htmlBase64,
                "--\(altBoundary)--",
            ].joined(separator: "\r\n")
            bodyPart = ("multipart/alternative; boundary=\"\(altBoundary)\"", payload)
        } else {
            bodyPart = ("text/plain; charset=UTF-8", plainBase64)
        }

        let attachedParts = draft.attachments.compactMap { attachment -> (Attachment, Data)? in
            guard let data = attachment.data else { return nil }
            return (attachment, data)
        }

        if !attachedParts.isEmpty {
            let mixedBoundary = "quill-mix-\(UUID().uuidString.replacing("-", with: ""))"
            headers.append("Content-Type: multipart/mixed; boundary=\"\(mixedBoundary)\"")
            var sections: [String] = []
            if draft.htmlBody != nil && !(draft.htmlBody?.isEmpty ?? true) {
                sections.append([
                    "--\(mixedBoundary)",
                    "Content-Type: \(bodyPart.contentType)",
                    "",
                    bodyPart.payload,
                ].joined(separator: "\r\n"))
            } else {
                sections.append([
                    "--\(mixedBoundary)",
                    "Content-Type: \(bodyPart.contentType)",
                    "Content-Transfer-Encoding: base64",
                    "",
                    bodyPart.payload,
                ].joined(separator: "\r\n"))
            }
            for (attachment, data) in attachedParts {
                let filename = sanitizedFilename(attachment.filename)
                let encodedData = data.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])
                sections.append([
                    "--\(mixedBoundary)",
                    "Content-Type: \(attachment.resolvedMIMEType); name=\"\(filename)\"",
                    "Content-Disposition: attachment; filename=\"\(filename)\"",
                    "Content-Transfer-Encoding: base64",
                    "",
                    encodedData,
                ].joined(separator: "\r\n"))
            }
            sections.append("--\(mixedBoundary)--")
            return Data((headers.joined(separator: "\r\n") + "\r\n\r\n" + sections.joined(separator: "\r\n") + "\r\n").utf8)
        }

        if draft.htmlBody != nil && !(draft.htmlBody?.isEmpty ?? true) {
            headers.append("Content-Type: \(bodyPart.contentType)")
            return Data((headers.joined(separator: "\r\n") + "\r\n\r\n" + bodyPart.payload + "\r\n").utf8)
        }

        headers += [
            "Content-Type: text/plain; charset=UTF-8",
            "Content-Transfer-Encoding: base64",
        ]
        return Data((headers.joined(separator: "\r\n") + "\r\n\r\n" + plainBase64 + "\r\n").utf8)
    }

    private static func sanitizedFilename(_ name: String) -> String {
        let clean = sanitizedHeader(name)
            .replacing("\\", with: "_")
            .replacing("\"", with: "'")
        return clean.isEmpty ? "attachment" : clean
    }

    private static func htmlDocument(body: String, quoted: String?) -> String {
        var html = body
        if let quoted, !quoted.isEmpty {
            let escaped = quoted
                .replacing("&", with: "&amp;")
                .replacing("<", with: "&lt;")
                .replacing(">", with: "&gt;")
                .replacing("\n", with: "<br>")
            html += "<br><blockquote style=\"margin:0 0 0 0.8ex;border-left:1px solid #ccc;padding-left:1ex;\">\(escaped)</blockquote>"
        }
        return "<!doctype html><html><body style=\"font-family:-apple-system,sans-serif;font-size:15px;line-height:1.45;\">\(html)</body></html>"
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
        let email = sanitizedHeader(contact.email)
        let rawName = sanitizedHeader(contact.name)
        guard !rawName.isEmpty else { return email }
        let name =
            rawName.allSatisfy(\.isASCII)
            ? "\"\(rawName.replacing("\\", with: "\\\\").replacing("\"", with: "\\\""))\""
            : encoded(rawName)
        return "\(name) <\(email)>"
    }

    /// Header text outside ASCII, wrapped as an RFC 2047 encoded word.
    private static func encoded(_ text: String) -> String {
        let line = sanitizedHeader(text)
        guard !line.allSatisfy(\.isASCII) else { return line }
        return "=?UTF-8?B?\(Data(line.utf8).base64EncodedString())?="
    }

    /// Removes carriage returns and line feeds so user input cannot inject extra headers.
    private static func sanitizedHeader(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ")
    }
}
