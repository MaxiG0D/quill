/// Everything the app needs to draw a mailbox.
struct MailSnapshot: Sendable {
    var account: Contact
    var labels: [MailLabel]
    var threads: [MailThread]
}
