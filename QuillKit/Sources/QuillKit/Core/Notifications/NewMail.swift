/// A message that has just arrived and is worth a notification.
struct NewMail: Hashable, Sendable {
    let threadID: MailThread.ID
    let messageID: Message.ID
    let sender: String
    let subject: String
    let preview: String
}
