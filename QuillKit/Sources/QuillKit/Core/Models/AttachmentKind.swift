/// The glyph families an attachment can show.
enum AttachmentKind: String, Sendable, CaseIterable {
    case pdf, image, document, file

    init(filename: String) {
        let ext = filename.split(separator: ".").last.map { $0.lowercased() } ?? ""
        switch ext {
        case "pdf": self = .pdf
        case "jpg", "jpeg", "png", "heic", "gif", "webp": self = .image
        case "doc", "docx", "pages", "rtf", "txt", "md": self = .document
        default: self = .file
        }
    }

    /// The three-letter badge shown on the glyph.
    var badge: String {
        switch self {
        case .pdf: "PDF"
        case .image: "JPG"
        case .document: "DOC"
        case .file: "FILE"
        }
    }

    var tone: LabelTone {
        switch self {
        case .pdf: .plum
        case .image: .amber
        case .document: .slate
        case .file: .olive
        }
    }
}
