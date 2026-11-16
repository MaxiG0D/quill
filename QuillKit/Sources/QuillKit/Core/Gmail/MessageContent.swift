import Foundation

/// Finds the readable text and the attachments in a message's MIME tree.
enum MessageContent {
    /// The plain-text part when there is one, otherwise the HTML part as text.
    static func text(of part: GmailResource.Part?) -> String {
        guard let part else { return "" }
        if let plain = first("text/plain", in: part).flatMap(decoded) {
            return plain.replacing("\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let html = first("text/html", in: part).flatMap(decoded) {
            return HTMLText.plain(from: html)
        }
        return ""
    }

    /// The HTML part, for mail that needs its layout to make sense: mail with no text
    /// version, and designed mail built from tables and images. A plain note that merely
    /// arrives with an HTML copy reads better as text.
    static func designedHTML(of part: GmailResource.Part?) -> String? {
        guard let part, let html = first("text/html", in: part).flatMap(decoded) else { return nil }
        let hasText = first("text/plain", in: part) != nil
        let isDesigned = html.contains(#/(?i)<(table|img)\b/#)
        return hasText && !isDesigned ? nil : html
    }

    static func attachments(of part: GmailResource.Part?, messageID: String) -> [Attachment] {
        guard let part else { return [] }
        var found: [Attachment] = []
        if let filename = part.filename, !filename.isEmpty, part.body?.attachmentId != nil {
            found.append(
                Attachment(
                    id: "\(messageID)/\(part.partId ?? filename)",
                    filename: filename,
                    byteCount: part.body?.size ?? 0
                )
            )
        }
        for child in part.parts ?? [] {
            found += attachments(of: child, messageID: messageID)
        }
        return found
    }

    /// The first body part of a type, searching depth first and skipping attached files.
    private static func first(_ mimeType: String, in part: GmailResource.Part) -> GmailResource.Part? {
        let isFile = !(part.filename ?? "").isEmpty
        if !isFile, part.mimeType?.lowercased() == mimeType, part.body?.data != nil {
            return part
        }
        for child in part.parts ?? [] {
            if let match = first(mimeType, in: child) {
                return match
            }
        }
        return nil
    }

    private static func decoded(_ part: GmailResource.Part) -> String? {
        guard let data = part.body?.data.flatMap({ Data(base64URLEncoded: $0) }) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }
}
