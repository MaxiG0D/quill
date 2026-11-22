import Foundation

/// Signs in to Google and hands out access tokens, refreshing them as they run out.
actor GoogleAuth {
    nonisolated let client: GoogleClient

    private let http: any HTTPClient
    private let tokens: any TokenStore
    private let clock: @Sendable () -> Date

    private var token: OAuthToken?
    private var hasLoaded = false
    private var refresh: Task<OAuthToken, any Error>?
    private var signedOutHandler: (@Sendable () async -> Void)?

    private static let authorizeURL = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenURL = "https://oauth2.googleapis.com/token"
    private static let revokeURL = "https://oauth2.googleapis.com/revoke"

    init(
        client: GoogleClient,
        http: any HTTPClient = URLSessionHTTPClient(),
        tokens: any TokenStore = KeychainTokenStore(),
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.client = client
        self.http = http
        self.tokens = tokens
        self.clock = clock
    }

    /// Called when Google withdraws the sign-in, so the app can return to the sign-in screen.
    func onSignedOut(_ handler: @escaping @Sendable () async -> Void) {
        signedOutHandler = handler
    }

    func isSignedIn() async -> Bool {
        await current() != nil
    }

    /// The page where the person approves the sign-in.
    nonisolated func authorizationURL(challenge: String, state: String, selectAccount: Bool = false) -> URL? {
        var components = URLComponents(string: Self.authorizeURL)
        var items = [
            URLQueryItem(name: "client_id", value: client.id),
            URLQueryItem(name: "redirect_uri", value: client.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleClient.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        if selectAccount {
            items.append(URLQueryItem(name: "prompt", value: "select_account"))
        }
        components?.queryItems = items
        return components?.url
    }

    /// Finishes a sign-in from the URL Google redirected to.
    func signIn(callback: URL, verifier: String, state: String) async throws {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }
        if let reason = value("error") {
            throw GoogleAuthError.denied(reason)
        }
        guard let code = value("code"), value("state") == state else {
            throw GoogleAuthError.invalidCallback
        }

        let grant = try await requestToken([
            ("client_id", client.id),
            ("code", code),
            ("code_verifier", verifier),
            ("grant_type", "authorization_code"),
            ("redirect_uri", client.redirectURI),
        ])
        // Google lets people untick individual permissions, and still signs them in.
        if let scope = grant.scope, !scope.contains("gmail.modify") {
            throw GoogleAuthError.mailNotAllowed
        }
        guard let refreshToken = grant.refreshToken else {
            throw GoogleAuthError.server("")
        }
        try await store(
            OAuthToken(accessToken: grant.accessToken, refreshToken: refreshToken, expiry: expiry(of: grant))
        )
    }

    /// A token that is good for at least the next minute.
    func accessToken() async throws -> String {
        try await credentials().accessToken
    }

    /// Forces a fresh access token from Google, used when an API call returns HTTP 401 before local expiry.
    func forceRefreshAccessToken() async throws -> String {
        guard let token = await current() else {
            throw GoogleAuthError.signedOut
        }
        if let refresh {
            return try await refresh.value.accessToken
        }
        let task = Task { try await self.refreshed(token) }
        refresh = task
        defer { refresh = nil }
        return try await task.value.accessToken
    }

    /// The account's tokens, with an access token that is good for at least the next minute.
    func credentials() async throws -> OAuthToken {
        guard let token = await current() else {
            throw GoogleAuthError.signedOut
        }
        if token.isFresh(at: clock()) {
            return token
        }
        if let refresh {
            return try await refresh.value
        }
        let task = Task { try await self.refreshed(token) }
        refresh = task
        defer { refresh = nil }
        return try await task.value
    }

    /// Forgets the account here and asks Google to withdraw the token.
    func signOut() async {
        let token = await current()
        await forget()
        guard let token, let url = URL(string: Self.revokeURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormEncoding.body([("token", token.refreshToken)])
        _ = try? await http.send(request)
    }

    private func current() async -> OAuthToken? {
        if !hasLoaded {
            token = try? await tokens.load()
            hasLoaded = true
        }
        return token
    }

    private func store(_ token: OAuthToken) async throws {
        self.token = token
        hasLoaded = true
        try await tokens.save(token)
    }

    private func forget() async {
        token = nil
        hasLoaded = true
        try? await tokens.clear()
    }

    private func refreshed(_ old: OAuthToken) async throws -> OAuthToken {
        do {
            let grant = try await requestToken([
                ("client_id", client.id),
                ("grant_type", "refresh_token"),
                ("refresh_token", old.refreshToken),
            ])
            let token = OAuthToken(
                accessToken: grant.accessToken,
                refreshToken: grant.refreshToken ?? old.refreshToken,
                expiry: expiry(of: grant)
            )
            try await store(token)
            return token
        } catch GoogleAuthError.signedOut {
            await forget()
            await signedOutHandler?()
            throw GoogleAuthError.signedOut
        }
    }

    private func expiry(of grant: TokenGrant) -> Date {
        clock().addingTimeInterval(TimeInterval(grant.expiresIn ?? 3600))
    }

    private func requestToken(_ fields: [(String, String)]) async throws -> TokenGrant {
        guard let url = URL(string: Self.tokenURL) else {
            throw GoogleAuthError.server("")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormEncoding.body(fields)

        let (data, response) = try await http.send(request)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard (200..<300).contains(response.statusCode) else {
            let failure = try? decoder.decode(TokenFailure.self, from: data)
            if failure?.error == "invalid_grant" {
                throw GoogleAuthError.signedOut
            }
            throw GoogleAuthError.server(failure?.errorDescription ?? "")
        }
        return try decoder.decode(TokenGrant.self, from: data)
    }

    private struct TokenGrant: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int?
        let scope: String?
    }

    private struct TokenFailure: Decodable {
        let error: String?
        let errorDescription: String?
    }
}
