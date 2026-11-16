import WebKit

/// Fetches the pictures of designed mail before it is opened, so opening it has nothing to wait for.
///
/// Each message is loaded in a web view that is never shown. What it fetches lands in the
/// store every message shares, where the message finds it when it is opened.
@MainActor
final class MessagePreloader {
    static let shared = MessagePreloader()

    /// How many messages are prepared ahead: about a screenful of mail.
    private static let limit = 8

    private var view: WKWebView?
    private var seen: Set<Message.ID> = []
    private var task: Task<Void, Never>?

    /// Prepares the newest designed messages among these threads, one at a time.
    func prepare(_ threads: [MailThread]) {
        let messages = Array(
            threads
                .compactMap(\.messages.last)
                .filter { $0.html != nil && !seen.contains($0.id) }
                .prefix(Self.limit)
        )
        guard !messages.isEmpty else { return }
        let pages = messages.compactMap(\.html)
        seen.formUnion(messages.map(\.id))

        let earlier = task
        task = Task {
            await earlier?.value
            let view = self.view ?? MessageWebView.makeHiddenView()
            self.view = view
            for page in pages {
                view.loadHTMLString(HTMLDocument.page(for: page), baseURL: nil)
                // A slow sender is given a few seconds, then left behind.
                for _ in 0..<25 {
                    try? await Task.sleep(for: .milliseconds(200))
                    if !view.isLoading { break }
                }
            }
            view.loadHTMLString("", baseURL: nil)
        }
    }

    func forget() {
        task?.cancel()
        seen = []
    }
}
