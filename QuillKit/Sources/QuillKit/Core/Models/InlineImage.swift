import Foundation

/// An image embedded inside an HTML message via `cid:` rather than shown as a file attachment.
struct InlineImage: Hashable, Codable, Sendable {
    /// The normalized `Content-ID` without angle brackets.
    let contentID: String
    let messageID: String
    let attachmentID: String
    let mimeType: String
}
