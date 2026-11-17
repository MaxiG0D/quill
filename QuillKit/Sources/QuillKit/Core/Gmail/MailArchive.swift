import Foundation

/// The mailbox as last seen, kept on the device so Quill opens at once and works offline.
/// It also holds what Gmail has no place for: pins and snoozes.
struct MailArchive: Codable, Sendable {
    /// Raised whenever threads start keeping something more from Gmail.
    static let currentFormat = 2

    /// The format this archive was written in. Older archives carry none.
    var format: Int? = MailArchive.currentFormat
    var account: Contact
    var labels: [MailLabel] = []
    /// Inbox first, then the rest, in the order Gmail listed them.
    var threads: [MailThread] = []
    /// Each thread's history ID when it was fetched. A different one from Gmail means the thread changed.
    var historyIDs: [MailThread.ID: String] = [:]
    var anchors: [MailThread.ID: ReplyAnchor] = [:]
    var pinned: Set<MailThread.ID> = []
    var snoozed: [MailThread.ID: Date] = [:]
    /// Gmail labels whose own mail is listed on every refresh, most recently opened first.
    /// Older archives carry none.
    var watched: [String]?

    var snapshot: MailSnapshot {
        MailSnapshot(account: account, labels: labels, threads: threads)
    }

    /// The same mailbox, with every thread due to be fetched again when it was written in an
    /// older format. Its threads still show in the meantime.
    var current: MailArchive {
        guard format != Self.currentFormat else { return self }
        var archive = self
        archive.format = Self.currentFormat
        archive.historyIDs = [:]
        return archive
    }

    func thread(_ id: MailThread.ID) -> MailThread? {
        threads.first { $0.id == id }
    }

    /// Puts the device's own pins and snoozes on a thread fresh from Gmail.
    func decorated(_ thread: MailThread) -> MailThread {
        var thread = thread
        thread.isPinned = pinned.contains(thread.id)
        thread.snoozedUntil = snoozed[thread.id]
        return thread
    }
}
