import Foundation

/// The parts of Gmail's API responses that Quill reads.
enum GmailResource {
    struct ThreadList: Decodable, Sendable {
        var threads: [ThreadReference]?
    }

    /// A thread's ID and the history ID that changes whenever the thread does.
    struct ThreadReference: Decodable, Hashable, Sendable {
        let id: String
        var historyId: String?
    }

    struct Thread: Decodable, Sendable {
        let id: String
        var historyId: String?
        var messages: [Message]?
    }

    struct Message: Decodable, Sendable {
        let id: String
        var labelIds: [String]?
        /// Milliseconds since 1970, as text.
        var internalDate: String?
        /// Gmail's one-line summary, with HTML entities.
        var snippet: String?
        var payload: Part?

        func has(_ label: String) -> Bool {
            labelIds?.contains(label) ?? false
        }

        func header(_ name: String) -> String? {
            payload?.headers?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        var date: Date {
            let milliseconds = internalDate.flatMap(Double.init) ?? 0
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
    }

    /// One node of a message's MIME tree.
    struct Part: Decodable, Sendable {
        var partId: String?
        var mimeType: String?
        var filename: String?
        var headers: [Header]?
        var body: Body?
        var parts: [Part]?
    }

    struct Header: Decodable, Sendable {
        let name: String
        let value: String
    }

    struct Body: Decodable, Sendable {
        var size: Int?
        /// URL-safe base64.
        var data: String?
        var attachmentId: String?
    }

    struct LabelList: Decodable, Sendable {
        var labels: [Label]?
    }

    struct Label: Decodable, Sendable {
        let id: String
        let name: String
        /// "system" or "user".
        var type: String?
    }

    struct UserInfo: Decodable, Sendable {
        let email: String
        var name: String?
        /// The address of the account's Google picture.
        var picture: String?

        /// The picture at a size that stays sharp in the largest avatar. Google sends a small one by default.
        var photoURL: URL? {
            guard let picture else { return nil }
            guard let size = picture.range(of: "=s", options: .backwards) else { return URL(string: picture) }
            return URL(string: picture[..<size.lowerBound] + "=s192-c")
        }
    }

    struct LabelChange: Encodable, Sendable {
        var addLabelIds: [String] = []
        var removeLabelIds: [String] = []
    }

    struct OutgoingMessage: Encodable, Sendable {
        /// The whole message in URL-safe base64.
        let raw: String
        var threadId: String?
    }

    /// Stands in for a response Quill has no use for.
    struct Ignored: Decodable, Sendable {}
}
