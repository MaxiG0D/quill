/// A Gmail thread as Quill shows it, with what is needed to act on it later.
struct MappedThread: Sendable {
    var thread: MailThread
    var anchor: ReplyAnchor
    var historyId: String?
}
