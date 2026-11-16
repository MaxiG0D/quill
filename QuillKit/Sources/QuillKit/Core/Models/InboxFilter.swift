enum InboxFilter: String, CaseIterable, Identifiable, Sendable {
    case all, unread, starred, attachments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Mail"
        case .unread: "Unread"
        case .starred: "Starred"
        case .attachments: "Attachments"
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .unread: "circle.fill"
        case .starred: "star"
        case .attachments: "paperclip"
        }
    }

    func matches(_ thread: MailThread) -> Bool {
        switch self {
        case .all: true
        case .unread: thread.isUnread
        case .starred: thread.isStarred
        case .attachments: thread.hasAttachments
        }
    }
}
