/// Everything the app needs to draw a mailbox.
struct MailSnapshot: Sendable {
    var account: Contact
    var labels: [MailLabel]
    var threads: [MailThread]
    /// Unread threads in the whole Inbox as Gmail counts them, when known.
    var inboxUnread: Int?
    /// False when the service is still gathering mail and a later snapshot will hold more.
    var isComplete = true
    /// How much of the mailbox has arrived so far, from 0 to 1.
    var progress = 1.0
}
