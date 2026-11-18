import Foundation
import Security

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
    func register(_ deviceToken: String, activityStartToken: String? = nil) async throws {
        let credentials = try await auth.credentials()
        let registration = Registration(
            deviceToken: deviceToken,
            environment: Self.environment,
            platform: Self.platform,
            refreshToken: credentials.refreshToken,
            activityStartToken: activityStartToken
        )
        try await send("POST", registration, accessToken: credentials.accessToken)
    }

    /// Asks the relay to send this account's devices a made-up sign-in code, for trying the alert.
    func sendTestCode() async throws {
        let credentials = try await auth.credentials()
        var request = URLRequest(url: devices.deletingLastPathComponent().appending(path: "test-code"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await http.send(request)
        guard (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
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
        let activityStartToken: String?
    }

    private struct Removal: Encodable {
        let deviceToken: String
    }

    /// Which of Apple's push services holds this build's device token. That is decided by
    /// how the app was signed, not by how it was compiled, so it is read from the signature.
    static let environment: String = signedEnvironment() ?? "production"

    private static func signedEnvironment() -> String? {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        let name = "com.apple.developer.aps-environment" as CFString
        return SecTaskCopyValueForEntitlement(task, name, nil) as? String
        #else
        // iOS keeps the entitlements out of reach, but builds installed outside the App
        // Store carry the profile that grants them. App Store builds carry none.
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let profile = String(data: data, encoding: .isoLatin1) else { return nil }
        return environment(inProfile: profile)
        #endif
    }

    /// The `aps-environment` value in a provisioning profile's text.
    static func environment(inProfile profile: String) -> String? {
        guard let key = profile.range(of: "<key>aps-environment</key>"),
              let open = profile.range(of: "<string>", range: key.upperBound..<profile.endIndex),
              let close = profile.range(of: "</string>", range: open.upperBound..<profile.endIndex) else { return nil }
        return String(profile[open.upperBound..<close.lowerBound])
    }

    private static var platform: String {
        #if os(macOS)
        "macos"
        #else
        "ios"
        #endif
    }
}
