/// What the thread list is showing: a mailbox or everything under one label.
enum MailboxSelection: Hashable, Sendable {
    case mailbox(Mailbox)
    case label(MailLabel.ID)
}
