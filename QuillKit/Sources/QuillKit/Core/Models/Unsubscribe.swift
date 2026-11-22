import Foundation

/// The ways a mailing list offers to stop sending, read from its `List-Unsubscribe` headers.
struct Unsubscribe: Hashable, Codable, Sendable {
    /// An address that unsubscribes with a single POST, per RFC 8058.
    var oneClick: URL?
    /// An address to write to, with the subject and body the list asks for.
    var mail: Mail?
    /// A page where the person finishes unsubscribing themselves.
    var page: URL?

    struct Mail: Hashable, Codable, Sendable {
        var address: String
        var subject: String?
        var body: String?
    }

    /// Nil when the headers offer no usable way out.
    init?(list header: String?, post: String?) {
        guard let header else { return nil }
        var web: URL?
        for entry in Self.entries(in: header) {
            guard let url = URL(string: entry), let scheme = url.scheme?.lowercased() else { continue }
            if scheme == "mailto", mail == nil {
                mail = Self.mail(from: entry)
            } else if scheme == "https", url.host() != nil {
                if web?.scheme?.lowercased() != "https" {
                    web = url
                }
            } else if scheme == "http", web == nil, url.host() != nil {
                web = url
            }
        }
        let isOneClick = post?.filter { !$0.isWhitespace }
            .caseInsensitiveCompare("List-Unsubscribe=One-Click") == .orderedSame
        if isOneClick, web?.scheme?.lowercased() == "https" {
            oneClick = web
        }
        page = web
        guard oneClick != nil || mail != nil || page != nil else { return nil }
    }

    /// The addresses between angle brackets, with any folding whitespace removed.
    private static func entries(in header: String) -> [String] {
        header.split(separator: "<").compactMap { part in
            guard let end = part.firstIndex(of: ">") else { return nil }
            let entry = part[..<end].filter { !$0.isWhitespace }
            return entry.isEmpty ? nil : String(entry)
        }
    }

    private static func mail(from entry: String) -> Mail? {
        guard let components = URLComponents(string: entry) else { return nil }
        let address = components.path.removingPercentEncoding ?? components.path
        guard address.contains("@"), !address.contains(",") else { return nil }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
        return Mail(address: address, subject: value("subject"), body: value("body"))
    }
}

/// How an unsubscribe went.
enum UnsubscribeOutcome: Equatable, Sendable {
    /// The list was told, and should stop sending.
    case done
    /// Only the list's own page can finish it.
    case openPage(URL)
}
