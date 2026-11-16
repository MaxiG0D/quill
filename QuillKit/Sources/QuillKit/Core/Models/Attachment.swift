import Foundation

struct Attachment: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var filename: String
    var byteCount: Int

    init(id: String = UUID().uuidString, filename: String, byteCount: Int = 0) {
        self.id = id
        self.filename = filename
        self.byteCount = byteCount
    }

    var kind: AttachmentKind {
        AttachmentKind(filename: filename)
    }
}
