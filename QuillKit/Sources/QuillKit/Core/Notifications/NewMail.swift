/// A message that has just arrived and is worth a notification.
struct NewMail: Hashable, Sendable {
    let threadID: MailThread.ID
    let messageID: Message.ID
    let sender: String
    /// The sender's address, which finds their picture. Empty when unknown.
    var address = ""
    let subject: String
    let preview: String
}
