/// A thread that matched a search, with the line of text to show for it.
struct SearchResult: Identifiable, Hashable, Sendable {
    let thread: MailThread
    let excerpt: String

    var id: MailThread.ID { thread.id }
}
