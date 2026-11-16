/// The fixed mailboxes. Starred and Snoozed are views over the others.
enum Mailbox: String, CaseIterable, Identifiable, Codable, Sendable {
    case inbox, starred, snoozed, sent, drafts, archive, trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .starred: "Starred"
        case .snoozed: "Snoozed"
        case .sent: "Sent"
        case .drafts: "Drafts"
        case .archive: "Archive"
        case .trash: "Trash"
        }
    }

    var symbol: String {
        switch self {
        case .inbox: "tray"
        case .starred: "star"
        case .snoozed: "clock"
        case .sent: "paperplane"
        case .drafts: "doc"
        case .archive: "archivebox"
        case .trash: "trash"
        }
    }
}
