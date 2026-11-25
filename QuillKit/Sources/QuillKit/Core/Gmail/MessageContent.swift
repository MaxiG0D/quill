import Foundation

/// Finds the readable text and the attachments in a message's MIME tree.
enum MessageContent {
    /// The plain-text part when there is one, otherwise the HTML part as text.
    static func text(of part: GmailResource.Part?) -> String {
        guard let part else { return "" }
        if let plain = first("text/plain", in: part).flatMap(decoded) {
            let trimmed = plain.replacing("\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
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
        guard let part, var html = first("text/html", in: part).flatMap(decoded) else { return nil }
        let plain = first("text/plain", in: part).flatMap(decoded)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasText = !plain.isEmpty
        let isDesigned = html.contains(#/(?i)<(table|img)\b/#)
        guard !hasText || isDesigned else { return nil }
        // Resolve any inline `cid:` images whose bytes were already delivered inside the MIME payload.
        let embeddedData = embeddedInlineData(in: part)
        if !embeddedData.isEmpty {
            for (cid, dataURI) in embeddedData {
                html = html.replacing("cid:\(cid)", with: dataURI)
            }
        }
        return html
    }

    /// Embedded `cid:` images that must be downloaded from Gmail via their attachment ID.
    static func inlineImages(of part: GmailResource.Part?, messageID: String) -> [InlineImage] {
        guard let part else { return [] }
        var found: [InlineImage] = []
        if let mimeType = part.mimeType?.lowercased(), mimeType.hasPrefix("image/"),
           let cid = contentID(in: part),
           let attachmentID = part.body?.attachmentId {
            found.append(InlineImage(contentID: cid, messageID: messageID, attachmentID: attachmentID, mimeType: mimeType))
        }
        for child in part.parts ?? [] {
            found += inlineImages(of: child, messageID: messageID)
        }
        return found
    }

    private static func embeddedInlineData(in part: GmailResource.Part) -> [String: String] {
        var found: [String: String] = [:]
        if let mimeType = part.mimeType?.lowercased(), mimeType.hasPrefix("image/"),
           let cid = contentID(in: part),
           let raw = part.body?.data,
           let data = Data(base64URLEncoded: raw) {
            found[cid] = "data:\(mimeType);base64,\(data.base64EncodedString())"
        }
        for child in part.parts ?? [] {
            found.merge(embeddedInlineData(in: child)) { existing, _ in existing }
        }
        return found
    }

    private static func contentID(in part: GmailResource.Part) -> String? {
        guard let raw = part.headers?.first(where: { $0.name.caseInsensitiveCompare("Content-ID") == .orderedSame })?.value else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let unwrapped = trimmed.hasPrefix("<") && trimmed.hasSuffix(">")
            ? String(trimmed.dropFirst().dropLast())
            : trimmed
        return unwrapped.isEmpty ? nil : unwrapped
    }

    static func attachments(of part: GmailResource.Part?, messageID: String) -> [Attachment] {
        guard let part else { return [] }
        var found: [Attachment] = []
        if let filename = part.filename, !filename.isEmpty, part.body?.attachmentId != nil, !isInlineImage(part) {
            found.append(
                Attachment(
                    id: "\(messageID)/\(part.partId ?? filename)",
                    filename: filename,
                    byteCount: part.body?.size ?? 0,
                    messageID: messageID,
                    attachmentID: part.body?.attachmentId,
                    mimeType: part.mimeType
                )
            )
        }
        for child in part.parts ?? [] {
            found += attachments(of: child, messageID: messageID)
        }
        return found
    }

    /// True for images embedded inside the HTML body (such as signature logos) rather than attached files.
    private static func isInlineImage(_ part: GmailResource.Part) -> Bool {
        guard part.mimeType?.lowercased().hasPrefix("image/") == true else { return false }
        let headers = part.headers ?? []
        let disposition = headers.first { $0.name.caseInsensitiveCompare("Content-Disposition") == .orderedSame }?.value.lowercased()
        let hasContentID = headers.contains { $0.name.caseInsensitiveCompare("Content-ID") == .orderedSame }
        return disposition?.hasPrefix("inline") == true && hasContentID
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
        return text(from: data, declared: charsetEncoding(in: part))
    }

    /// Valid UTF-8 wins over a declared legacy charset, since senders often mislabel UTF-8 as Latin-1 or Windows-1252.
    static func text(from data: Data, declared: String.Encoding?) -> String? {
        let utf8 = String(data: data, encoding: .utf8)
        let isLegacy = declared == .isoLatin1 || declared == .windowsCP1252 || declared == .ascii
        let decoded: String?
        if let utf8, declared == nil || isLegacy || declared == .utf8 {
            decoded = utf8
        } else if let declared, let text = String(data: data, encoding: declared) {
            decoded = text
        } else {
            decoded = utf8 ?? String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .isoLatin1)
        }
        return decoded.map(repairingMojibake)
    }

    /// Fixes text whose UTF-8 bytes were read as Windows-1252 ("demandÃ©" becomes "demandé"). Text that doesn't round-trip is left alone.
    static func repairingMojibake(_ text: String) -> String {
        guard text.contains(where: { $0 == "Ã" || $0 == "â" || $0 == "Â" }) else { return text }
        var current = text
        for _ in 0..<2 {
            guard let bytes = current.data(using: .windowsCP1252) ?? latin1Bytes(current),
                  let fixed = String(data: bytes, encoding: .utf8), fixed != current else { break }
            current = fixed
        }
        return current
    }

    /// Latin-1 bytes for text where Windows-1252 has no mapping (such as the C1 controls 0x81 or 0x8D).
    private static func latin1Bytes(_ text: String) -> Data? {
        var bytes = Data()
        for scalar in text.unicodeScalars {
            if let cp = String(scalar).data(using: .windowsCP1252) { bytes.append(cp) }
            else if scalar.value < 256 { bytes.append(UInt8(scalar.value)) }
            else { return nil }
        }
        return bytes
    }

    private static func charsetEncoding(in part: GmailResource.Part) -> String.Encoding? {
        guard let contentType = part.headers?.first(where: { $0.name.caseInsensitiveCompare("Content-Type") == .orderedSame })?.value,
              let match = contentType.firstMatch(of: #/(?i)charset\s*=\s*"?([A-Za-z0-9._-]+)"?/#) else {
            return nil
        }
        let name = String(match.1)
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }
}
