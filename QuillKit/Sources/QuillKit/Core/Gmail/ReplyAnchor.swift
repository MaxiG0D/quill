/// What a reply needs to know about the message it answers.
struct ReplyAnchor: Codable, Hashable, Sendable {
    /// Gmail's ID for the thread's latest message, the one a star or unread mark lands on.
    var latestMessageID: String
    /// The latest message's Message-ID header.
    var messageID: String?
    var references: String?
}
