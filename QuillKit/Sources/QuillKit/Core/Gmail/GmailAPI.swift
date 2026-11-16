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

    /// The newest threads matching a Gmail search and every given label. Spam and Trash are left out unless asked for.
    func threadReferences(query: String? = nil, labelIDs: [String] = [], limit: Int) async throws -> [GmailResource.ThreadReference] {
        var items = [URLQueryItem(name: "maxResults", value: String(limit))]
        if let query {
            items.append(URLQueryItem(name: "q", value: query))
        }
        items += labelIDs.map { URLQueryItem(name: "labelIds", value: $0) }
        let list: GmailResource.ThreadList = try await call(Self.mail + "threads", query: items)
        return list.threads ?? []
    }

    func thread(_ id: String) async throws -> GmailResource.Thread {
        try await call(Self.mail + "threads/\(id)", query: [URLQueryItem(name: "format", value: "full")])
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

    /// Sends a finished RFC 5322 message, joining `threadID` when it is a reply.
    func send(raw: Data, threadID: String?) async throws {
        let message = GmailResource.OutgoingMessage(raw: raw.base64URLEncoded, threadId: threadID)
        let _: GmailResource.Ignored = try await call(Self.mail + "messages/send", method: "POST", body: JSONEncoder().encode(message))
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
        for attempt in 1...attempts {
            var request = URLRequest(url: url)
            request.httpMethod = method
            let token = try await auth.accessToken()
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
