import Foundation

/// The Gmail REST calls Quill makes, each signed with the account's access token.
struct GmailAPI: Sendable {
    let auth: GoogleAuth
    var http: any HTTPClient = URLSessionHTTPClient()

    private static let mail = "https://gmail.googleapis.com/gmail/v1/users/me/"
    private static let userInfoURL = "https://openidconnect.googleapis.com/v1/userinfo"

    func userInfo() async throws -> GmailResource.UserInfo {
        try await call(Self.userInfoURL)
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

    /// Makes one call, waiting and trying again when Gmail asks Quill to slow down.
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
        var delay = Duration.milliseconds(500)
        let attempts = 4
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
            let isRateLimited = status == 429 || (status == 403 && failure?.status == "RESOURCE_EXHAUSTED")
            guard attempt < attempts, isRateLimited || status >= 500 else {
                throw GmailError.status(status, failure?.message ?? "")
            }
            try await Task.sleep(for: delay)
            delay = delay * 2
        }
        throw GmailError.status(429, "")
    }

    private struct Failure: Decodable {
        struct Detail: Decodable {
            var message: String?
            var status: String?
        }

        var error: Detail?
    }
}
