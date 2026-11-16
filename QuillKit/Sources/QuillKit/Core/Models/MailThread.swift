import Foundation

struct MailThread: Identifiable, Hashable, Sendable {
    let id: String
    var subject: String
    /// Oldest first.
    var messages: [Message]
    var labelIDs: [MailLabel.ID]
    /// Where the thread is filed. Never `.starred` or `.snoozed`, which are views.
    var folder: Mailbox
    var isUnread: Bool
    var isStarred: Bool
    var isPinned: Bool
    var snoozedUntil: Date?

    init(
        id: String = UUID().uuidString,
        subject: String,
        messages: [Message],
        labelIDs: [MailLabel.ID] = [],
        folder: Mailbox = .inbox,
        isUnread: Bool = false,
        isStarred: Bool = false,
        isPinned: Bool = false,
        snoozedUntil: Date? = nil
    ) {
        self.id = id
        self.subject = subject
        self.messages = messages
        self.labelIDs = labelIDs
        self.folder = folder
        self.isUnread = isUnread
        self.isStarred = isStarred
        self.isPinned = isPinned
        self.snoozedUntil = snoozedUntil
    }

    var latest: Message? { messages.last }
    var date: Date { latest?.date ?? .distantPast }
    var sender: Contact? { latest?.sender }
    var preview: String { latest?.preview ?? "" }
    var attachments: [Attachment] { messages.flatMap(\.attachments) }
    var hasAttachments: Bool { messages.contains { !$0.attachments.isEmpty } }

    /// Hidden until its snooze date passes.
    func isSnoozed(at now: Date) -> Bool {
        snoozedUntil.map { $0 > now } ?? false
    }

    /// Back in the inbox after a snooze. Rows mark these with a clock.
    func hasReturned(at now: Date) -> Bool {
        snoozedUntil.map { $0 <= now } ?? false
    }

    func belongs(to selection: MailboxSelection, at now: Date) -> Bool {
        let snoozed = isSnoozed(at: now)
        return switch selection {
        case .label(let id):
            labelIDs.contains(id) && folder != .trash
        case .mailbox(.starred):
            isStarred && folder != .trash
        case .mailbox(.snoozed):
            snoozed && folder != .trash
        case .mailbox(.inbox):
            folder == .inbox && !snoozed
        case .mailbox(let mailbox):
            folder == mailbox
        }
    }
}
