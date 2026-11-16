import Foundation

enum MailSearch {
    /// Threads matching every word of the query, newest first. Trash is left out.
    static func results(for query: String, in threads: [MailThread]) -> [SearchResult] {
        guard !TextMatcher.terms(in: query).isEmpty else { return [] }

        return threads
            .filter { $0.folder != .trash }
            .compactMap { thread -> SearchResult? in
                let people = thread.messages.map(\.sender.displayName).joined(separator: " ")
                let files = thread.attachments.map(\.filename).joined(separator: " ")
                let bodies = thread.messages.map(\.preview)
                let haystack = ([thread.subject, people, files] + bodies).joined(separator: " ")
                guard TextMatcher.matches(query, in: haystack) else { return nil }

                // Prefer the newest message that mentions the query for the excerpt.
                let body = bodies.last { !TextMatcher.ranges(of: query, in: $0).isEmpty } ?? thread.preview
                return SearchResult(thread: thread, excerpt: TextMatcher.excerpt(of: body, around: query))
            }
            .sorted { $0.thread.date > $1.thread.date }
    }
}
