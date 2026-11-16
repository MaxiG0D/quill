import Foundation

/// Remembers which messages the device has already seen, so each one is announced once.
///
/// Every message that arrives after `since` is recorded the first time a refresh brings it,
/// whether or not it earns a notification. Marking old mail unread later therefore
/// announces nothing.
struct NewMailLedger: Codable, Equatable, Sendable {
    /// How many message IDs are remembered. The oldest are forgotten first.
    static let limit = 2000

    /// Mail from before this moment is never announced.
    var since: Date
    /// Oldest first.
    private(set) var seen: [Message.ID] = []

    init(since: Date) {
        self.since = since
    }

    /// Records what is new in `threads` and returns the part worth announcing, oldest first:
    /// the latest message from someone else in each unread Inbox thread.
    mutating func collect(from threads: [MailThread], account: Contact, now: Date) -> [NewMail] {
        var known = Set(seen)
        var mail: [NewMail] = []
        for thread in threads.sorted(by: { $0.date < $1.date }) {
            let fresh = thread.messages.filter { $0.date > since && known.insert($0.id).inserted }
            guard !fresh.isEmpty else { continue }
            seen += fresh.map(\.id)

            let isWaiting = thread.folder == .inbox && thread.isUnread && !thread.isSnoozed(at: now)
            let incoming = fresh.last { $0.sender.email.caseInsensitiveCompare(account.email) != .orderedSame }
            guard isWaiting, let incoming else { continue }
            mail.append(
                NewMail(
                    threadID: thread.id,
                    messageID: incoming.id,
                    sender: incoming.sender.displayName,
                    subject: thread.subject,
                    preview: String(incoming.preview.prefix(240))
                )
            )
        }
        if seen.count > Self.limit {
            seen.removeFirst(seen.count - Self.limit)
        }
        return mail
    }
}
