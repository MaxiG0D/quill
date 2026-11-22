import Foundation
import UniformTypeIdentifiers

struct Attachment: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var filename: String
    var byteCount: Int
    /// The Gmail message containing this attachment, when fetched from a mail service.
    var messageID: String?
    /// The provider's attachment identifier used to download the file bytes.
    var attachmentID: String?
    var mimeType: String?
    /// Raw file bytes for newly attached outgoing files or downloaded previews. Never cached in `mailbox.json`.
    var data: Data?

    init(
        id: String = UUID().uuidString,
        filename: String,
        byteCount: Int = 0,
        messageID: String? = nil,
        attachmentID: String? = nil,
        mimeType: String? = nil,
        data: Data? = nil
    ) {
        self.id = id
        self.filename = filename
        self.byteCount = byteCount
        self.messageID = messageID
        self.attachmentID = attachmentID
        self.mimeType = mimeType
        self.data = data
    }

    var kind: AttachmentKind {
        AttachmentKind(filename: filename)
    }

    var resolvedMIMEType: String {
        if let mimeType, !mimeType.isEmpty { return mimeType }
        let ext = (filename as NSString).pathExtension
        if !ext.isEmpty, let type = UTType(filenameExtension: ext), let preferred = type.preferredMIMEType {
            return preferred
        }
        return "application/octet-stream"
    }

    /// True when the file bytes are either already in memory or downloadable from the mail service.
    var isAvailable: Bool {
        data != nil || (messageID != nil && attachmentID != nil)
    }

    private enum CodingKeys: String, CodingKey {
        case id, filename, byteCount, messageID, attachmentID, mimeType
    }
}
