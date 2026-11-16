/// Which messages of an open thread are expanded. Only the newest starts open.
struct MessageExpansion: Equatable, Sendable {
    private(set) var ids: Set<Message.ID>

    init(thread: MailThread) {
        ids = Set(thread.latest.map { [$0.id] } ?? [])
    }

    func contains(_ message: Message) -> Bool {
        ids.contains(message.id)
    }

    mutating func toggle(_ message: Message) {
        if !ids.insert(message.id).inserted {
            ids.remove(message.id)
        }
    }

    /// Opens a message that just arrived, such as a reply that was just sent.
    mutating func expandLatest(of thread: MailThread) {
        if let latest = thread.latest {
            ids.insert(latest.id)
        }
    }
}
