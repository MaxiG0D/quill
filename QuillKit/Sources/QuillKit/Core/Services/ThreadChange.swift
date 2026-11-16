import Foundation

/// A single edit to a thread, sent to the mail service after it is applied locally.
enum ThreadChange: Hashable, Sendable {
    case move(Mailbox)
    case setStarred(Bool)
    case setUnread(Bool)
    case setPinned(Bool)
    case snooze(Date?)

    func apply(to thread: inout MailThread) {
        switch self {
        case .move(let folder):
            thread.folder = folder
            thread.snoozedUntil = nil
        case .setStarred(let value):
            thread.isStarred = value
        case .setUnread(let value):
            thread.isUnread = value
        case .setPinned(let value):
            thread.isPinned = value
        case .snooze(let date):
            thread.snoozedUntil = date
        }
    }
}
