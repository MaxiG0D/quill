import Foundation

/// A single edit to a thread, sent to the mail service after it is applied locally.
enum ThreadChange: Hashable, Sendable {
    case move(Mailbox)
    case setStarred(Bool)
    case setUnread(Bool)
    case setPinned(Bool)
    case snooze(Date?)
    case setLabel(MailLabel.ID, Bool)
    /// Files the thread under a label: out of the Inbox, and out of the label it was moved from.
    case file(under: MailLabel.ID, leaving: MailLabel.ID?)

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
        case .setLabel(let label, let isOn):
            if !isOn {
                thread.labelIDs.removeAll { $0 == label }
            } else if !thread.labelIDs.contains(label) {
                thread.labelIDs.append(label)
            }
        case .file(let label, let old):
            thread.labelIDs.removeAll { $0 == old }
            if !thread.labelIDs.contains(label) {
                thread.labelIDs.append(label)
            }
            thread.snoozedUntil = nil
            if thread.folder == .inbox || thread.folder == .trash {
                thread.folder = .archive
            }
        }
    }
}
