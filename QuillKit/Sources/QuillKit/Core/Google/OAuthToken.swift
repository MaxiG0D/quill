import Foundation

struct OAuthToken: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiry: Date

    /// True while the access token has at least a minute left.
    func isFresh(at now: Date) -> Bool {
        expiry.timeIntervalSince(now) > 60
    }
}
