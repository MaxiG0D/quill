import Foundation

/// The Gmail REST calls Quill makes, each signed with the account's access token.
struct GmailAPI: Sendable {
    let auth: GoogleAuth
    var http: any HTTPClient = URLSessionHTTPClient()

    private static let mail = "https://gmail.googleapis.com/gmail/v1/users/me/"
    private static let userInfoURL = "https://openidconnect.googleapis.com/v1/userinfo"
    private static let people = "https://people.googleapis.com/v1/"
    /// How many pages of a thousand people are read from each list.
    private static let peoplePages = 5

    func userInfo() async throws -> GmailResource.UserInfo {
        try await call(Self.userInfoURL)
    }

    /// Pictures of the people the account knows, by lowercased address. Empty when the
    /// account has not let Quill see its contacts.
    func contactPhotos() async -> [String: URL] {
        async let others = photos(in: "otherContacts", query: [
            URLQueryItem(name: "readMask", value: "emailAddresses,photos"),
            URLQueryItem(name: "sources", value: "READ_SOURCE_TYPE_CONTACT"),
            URLQueryItem(name: "sources", value: "READ_SOURCE_TYPE_PROFILE"),
        ])
        async let saved = photos(in: "people/me/connections", query: [
            URLQueryItem(name: "personFields", value: "emailAddresses,photos"),
        ])
        // A saved contact's picture wins over one Google gathered.
        return await others.merging(saved) { _, saved in saved }
    }

    private func photos(in list: String, query: [URLQueryItem]) async -> [String: URL] {
        var photos: [String: URL] = [:]
        var page: String?
        for _ in 0..<Self.peoplePages {
            var items = query + [URLQueryItem(name: "pageSize", value: "1000")]
            if let page {
                items.append(URLQueryItem(name: "pageToken", value: page))
            }
            guard let found: GmailResource.PersonList = try? await call(Self.people + list, query: items) else { break }
            for person in found.people {
                guard let url = person.photoURL else { continue }
                for address in person.addresses {
                    photos[address] = url
                }
            }
            guard let next = found.nextPageToken else { break }
            page = next
        }
        return photos
    }

    func labels() async throws -> [GmailResource.Label] {
        let list: GmailResource.LabelList = try await call(Self.mail + "labels")
        return list.labels ?? []
    }

    /// How many Inbox threads are unread in the whole mailbox, not only the ones on the device.
    /// Like Gmail's own badge it counts the Primary category only, and the whole Inbox when
    /// categories are off or unavailable. Primary's own tally also covers archived mail, so
    /// those threads are counted from the Inbox itself, in pages.
    func inboxUnread() async throws -> Int {
        if let primary: GmailResource.LabelCounts = try? await call(Self.mail + "labels/CATEGORY_PERSONAL"),
           (primary.threadsTotal ?? 0) > 0,
           let count = try? await unreadPrimaryInboxThreads() {
            return count
        }
        let counts: GmailResource.LabelCounts = try await call(Self.mail + "labels/INBOX")
        return counts.threadsUnread ?? 0
    }

    private func unreadPrimaryInboxThreads() async throws -> Int {
        var count = 0
        var pageToken: String?
        for _ in 0..<10 {
            let page = try await threadReferencePage(
                labelIDs: ["INBOX", "CATEGORY_PERSONAL", "UNREAD"],
                pageToken: pageToken,
                limit: 500
            )
            count += page.threads.count
            guard let next = page.nextPageToken else { break }
            pageToken = next
        }
        return count
    }

    func createLabel(name: String) async throws -> GmailResource.Label {
        let payload = GmailResource.LabelWrite(name: name)
        return try await call(Self.mail + "labels", method: "POST", body: JSONEncoder().encode(payload))
    }

    func renameLabel(_ id: String, to name: String) async throws -> GmailResource.Label {
        let payload = GmailResource.LabelWrite(name: name, labelListVisibility: nil, messageListVisibility: nil)
        return try await call(Self.mail + "labels/\(id)", method: "PATCH", body: JSONEncoder().encode(payload))
    }

    func deleteLabel(_ id: String) async throws {
        let _: GmailResource.Ignored = try await call(Self.mail + "labels/\(id)", method: "DELETE")
    }

    /// The newest threads matching a Gmail search and every given label. Spam and Trash are left out unless asked for.
    func threadReferences(
        query: String? = nil,
        labelIDs: [String] = [],
        includeSpamTrash: Bool = false,
        pageToken: String? = nil,
        limit: Int
    ) async throws -> [GmailResource.ThreadReference] {
        try await threadReferencePage(
            query: query,
            labelIDs: labelIDs,
            includeSpamTrash: includeSpamTrash,
            pageToken: pageToken,
            limit: limit
        ).threads
    }

    /// One page of thread references plus its continuation token for loading older mail.
    func threadReferencePage(
        query: String? = nil,
        labelIDs: [String] = [],
        includeSpamTrash: Bool = false,
        pageToken: String? = nil,
        limit: Int
    ) async throws -> (threads: [GmailResource.ThreadReference], nextPageToken: String?) {
        var items = [URLQueryItem(name: "maxResults", value: String(limit))]
        if let query {
            items.append(URLQueryItem(name: "q", value: query))
        }
        if includeSpamTrash {
            items.append(URLQueryItem(name: "includeSpamTrash", value: "true"))
        }
        if let pageToken {
            items.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        items += labelIDs.map { URLQueryItem(name: "labelIds", value: $0) }
        let list: GmailResource.ThreadList = try await call(Self.mail + "threads", query: items)
        return (list.threads ?? [], list.nextPageToken)
    }

    func thread(_ id: String) async throws -> GmailResource.Thread {
        try await call(Self.mail + "threads/\(id)", query: [URLQueryItem(name: "format", value: "full")])
    }

    /// Downloads raw attachment bytes for a message part.
    func attachment(messageID: String, id: String) async throws -> Data {
        let response: GmailResource.AttachmentData = try await call(Self.mail + "messages/\(messageID)/attachments/\(id)")
        guard let encoded = response.data, let data = Data(base64URLEncoded: encoded) else {
            throw GmailError.status(404, "Attachment data missing.")
        }
        return data
    }

    func modifyThread(_ id: String, adding: [String] = [], removing: [String] = []) async throws {
        let change = GmailResource.LabelChange(addLabelIds: adding, removeLabelIds: removing)
        let _: GmailResource.Ignored = try await call(Self.mail + "threads/\(id)/modify", method: "POST", body: JSONEncoder().encode(change))
    }

    func modifyMessage(_ id: String, adding: [String] = [], removing: [String] = []) async throws {
        let change = GmailResource.LabelChange(addLabelIds: adding, removeLabelIds: removing)
        let _: GmailResource.Ignored = try await call(Self.mail + "messages/\(id)/modify", method: "POST", body: JSONEncoder().encode(change))
    }

    func trashThread(_ id: String) async throws {
        let _: GmailResource.Ignored = try await call(Self.mail + "threads/\(id)/trash", method: "POST")
    }

    func untrashThread(_ id: String) async throws {
        let _: GmailResource.Ignored = try await call(Self.mail + "threads/\(id)/untrash", method: "POST")
    }

    /// Permanently deletes a thread from Gmail (cannot be undone).
    func deleteThread(_ id: String) async throws {
        let _: GmailResource.Ignored = try await call(Self.mail + "threads/\(id)", method: "DELETE")
    }

    /// Sends a finished RFC 5322 message, joining `threadID` when it is a reply.
    @discardableResult
    func send(raw: Data, threadID: String?) async throws -> GmailResource.SentMessage {
        let message = GmailResource.OutgoingMessage(raw: raw.base64URLEncoded, threadId: threadID)
        return try await call(Self.mail + "messages/send", method: "POST", body: JSONEncoder().encode(message))
    }

    func drafts(limit: Int = 50) async throws -> [GmailResource.DraftSummary] {
        let list: GmailResource.DraftList = try await call(Self.mail + "drafts", query: [URLQueryItem(name: "maxResults", value: String(limit))])
        return list.drafts ?? []
    }

    func createDraft(raw: Data, threadID: String?) async throws -> GmailResource.DraftSummary {
        let payload = GmailResource.OutgoingDraft(message: GmailResource.OutgoingMessage(raw: raw.base64URLEncoded, threadId: threadID))
        return try await call(Self.mail + "drafts", method: "POST", body: JSONEncoder().encode(payload))
    }

    func updateDraft(_ draftID: String, raw: Data, threadID: String?) async throws -> GmailResource.DraftSummary {
        let payload = GmailResource.OutgoingDraft(message: GmailResource.OutgoingMessage(raw: raw.base64URLEncoded, threadId: threadID))
        return try await call(Self.mail + "drafts/\(draftID)", method: "PUT", body: JSONEncoder().encode(payload))
    }

    func deleteDraft(_ draftID: String) async throws {
        let _: GmailResource.Ignored = try await call(Self.mail + "drafts/\(draftID)", method: "DELETE")
    }

    /// Unsubscribes from a mailing list as RFC 8058 describes: a bare POST, without the
    /// account's token or any cookies.
    func postOneClickUnsubscribe(to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("List-Unsubscribe=One-Click".utf8)
        let (_, response) = try await http.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw GmailError.status(response.statusCode, "")
        }
    }

    /// Makes one call. A server hiccup is retried after a pause. Running out of Gmail's
    /// per-minute allowance is not, since only waiting out the minute helps: it is thrown
    /// as `GmailError.rateLimited` for the caller to pace itself.
    private func call<Response: Decodable>(
        _ address: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Response {
        guard var components = URLComponents(string: address) else {
            throw URLError(.badURL)
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var delay = Duration.seconds(1)
        let attempts = 3
        var hasRefreshedAuth = false
        for attempt in 1...attempts {
            var request = URLRequest(url: url)
            request.httpMethod = method
            let token = hasRefreshedAuth ? try await auth.forceRefreshAccessToken() : try await auth.accessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let body {
                request.httpBody = body
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }

            let (data, response) = try await http.send(request)
            let status = response.statusCode
            if (200..<300).contains(status) {
                return try JSONDecoder().decode(Response.self, from: data.isEmpty ? Data("{}".utf8) : data)
            }

            if status == 401, !hasRefreshedAuth {
                hasRefreshedAuth = true
                continue
            }

            let failure = (try? JSONDecoder().decode(Failure.self, from: data))?.error
            if status == 429 || (status == 403 && failure?.isRateLimit == true) {
                throw GmailError.rateLimited
            }
            guard attempt < attempts, status >= 500 else {
                throw GmailError.status(status, failure?.message ?? "")
            }
            try await Task.sleep(for: delay)
            delay = delay * 2
        }
        throw GmailError.status(503, "")
    }

    private struct Failure: Decodable {
        struct Detail: Decodable {
            struct Item: Decodable {
                var reason: String?
            }

            var message: String?
            var status: String?
            var errors: [Item]?

            /// Gmail reports a spent allowance as a 403 with one of these marks.
            var isRateLimit: Bool {
                let reasons = Set(errors?.compactMap(\.reason) ?? [])
                return !reasons.isDisjoint(with: ["rateLimitExceeded", "userRateLimitExceeded"])
                    || status == "RESOURCE_EXHAUSTED"
                    || message?.hasPrefix("Quota exceeded") == true
            }
        }

        var error: Detail?
    }
}
