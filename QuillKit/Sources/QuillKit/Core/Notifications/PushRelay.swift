import Foundation

/// Quill's push relay: the small server that watches the Gmail account and sends this
/// device a notification the moment mail arrives. See `Relay/` in the repository.
///
/// The relay reads the mailbox with the account's refresh token, which is why registering
/// hands it over. The access token alongside proves whose account it is.
struct PushRelay: Sendable {
    private let devices: URL
    private let auth: GoogleAuth
    private let http: any HTTPClient

    /// Nil unless `address` is an https URL, so an unset address leaves push off.
    init?(address: String, auth: GoogleAuth, http: any HTTPClient = URLSessionHTTPClient()) {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: address), url.scheme == "https", url.host() != nil else { return nil }
        devices = url.appending(path: "devices")
        self.auth = auth
        self.http = http
    }

    /// Starts notifications to a device, or keeps them going. Called on every launch.
    func register(_ deviceToken: String) async throws {
        let credentials = try await auth.credentials()
        let registration = Registration(
            deviceToken: deviceToken,
            environment: Self.environment,
            platform: Self.platform,
            refreshToken: credentials.refreshToken
        )
        try await send("POST", registration, accessToken: credentials.accessToken)
    }

    /// Stops notifications to a device.
    func unregister(_ deviceToken: String) async throws {
        let credentials = try await auth.credentials()
        try await send("DELETE", Removal(deviceToken: deviceToken), accessToken: credentials.accessToken)
    }

    private func send(_ method: String, _ body: some Encodable, accessToken: String) async throws {
        var request = URLRequest(url: devices)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await http.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private struct Registration: Encodable {
        let deviceToken: String
        let environment: String
        let platform: String
        let refreshToken: String
    }

    private struct Removal: Encodable {
        let deviceToken: String
    }

    /// Which of Apple's push services holds this build's device token. Builds run from
    /// Xcode use the development one.
    private static var environment: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }

    private static var platform: String {
        #if os(macOS)
        "macos"
        #else
        "ios"
        #endif
    }
}
