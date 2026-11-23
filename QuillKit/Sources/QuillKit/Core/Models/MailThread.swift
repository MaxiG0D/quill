import Foundation

struct MailThread: Identifiable, Hashable, Codable, Sendable {
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
    /// True when this conversation includes at least one message sent by the account,
    /// so it also appears in the Sent mailbox even while filed in Inbox or Archive.
    var hasSentMessages: Bool
    /// The inbox tabs Gmail filed its messages under. Empty means Primary.
    /// Nil for a copy kept from before tabs existed, which is fetched again.
    var categories: Set<InboxCategory>?

    init(
        id: String = UUID().uuidString,
        subject: String,
        messages: [Message],
        labelIDs: [MailLabel.ID] = [],
        folder: Mailbox = .inbox,
        isUnread: Bool = false,
        isStarred: Bool = false,
        isPinned: Bool = false,
        snoozedUntil: Date? = nil,
        hasSentMessages: Bool = false,
        categories: Set<InboxCategory> = []
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
        self.hasSentMessages = hasSentMessages
        self.categories = categories
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        subject = try container.decode(String.self, forKey: .subject)
        messages = try container.decode([Message].self, forKey: .messages)
        labelIDs = try container.decode([MailLabel.ID].self, forKey: .labelIDs)
        folder = try container.decode(Mailbox.self, forKey: .folder)
        isUnread = try container.decode(Bool.self, forKey: .isUnread)
        isStarred = try container.decode(Bool.self, forKey: .isStarred)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        snoozedUntil = try container.decodeIfPresent(Date.self, forKey: .snoozedUntil)
        hasSentMessages = try container.decodeIfPresent(Bool.self, forKey: .hasSentMessages) ?? false
        categories = try container.decodeIfPresent(Set<InboxCategory>.self, forKey: .categories)
    }

    var latest: Message? { messages.last }
    var date: Date { latest?.date ?? .distantPast }
    var sender: Contact? { latest?.sender }
    var preview: String { latest?.preview ?? "" }
    var attachments: [Attachment] { messages.flatMap(\.attachments) }
    var hasAttachments: Bool { messages.contains { !$0.attachments.isEmpty } }

    /// The date used for sorting and sectioning: returning snoozes surface at their wake time.
    func displayDate(at now: Date) -> Date {
        if hasReturned(at: now), let wake = snoozedUntil {
            return max(date, wake)
        }
        return date
    }

    /// Hidden until its snooze date passes.
    func isSnoozed(at now: Date) -> Bool {
        snoozedUntil.map { $0 > now } ?? false
    }

    /// Back in the inbox after a snooze. Rows mark these with a clock.
    func hasReturned(at now: Date) -> Bool {
        snoozedUntil.map { $0 <= now } ?? false
    }

    /// Whether the thread shows under an inbox tab. Mail Gmail has not sorted counts as Primary.
    func isFiled(under category: InboxCategory) -> Bool {
        let filed = categories ?? []
        return filed.isEmpty ? category == .primary : filed.contains(category)
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
        case .mailbox(.sent):
            (folder == .sent || hasSentMessages) && folder != .trash
        case .mailbox(let mailbox):
            folder == mailbox
        }
    }
}
