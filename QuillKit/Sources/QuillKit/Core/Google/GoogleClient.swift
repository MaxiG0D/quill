import Foundation

/// The OAuth client Quill signs in with: an iOS client from Google Cloud Console.
struct GoogleClient: Hashable, Sendable {
    private static let suffix = ".apps.googleusercontent.com"

    /// Reading, filing and sending mail, the name and address shown for the account,
    /// and the contacts whose pictures appear beside their mail.
    static let scopes = [
        "https://www.googleapis.com/auth/gmail.modify",
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/contacts.readonly",
        "https://www.googleapis.com/auth/contacts.other.readonly",
    ]

    let id: String

    /// Nil unless `id` looks like a Google client ID, so an unset ID leaves the app on sample mail.
    init?(id: String) {
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.hasSuffix(Self.suffix), id.count > Self.suffix.count else { return nil }
        self.id = id
    }

    /// The URL scheme Google redirects to: the client ID with its parts reversed.
    var redirectScheme: String {
        id.split(separator: ".").reversed().joined(separator: ".")
    }

    var redirectURI: String {
        "\(redirectScheme):/oauth2redirect"
    }
}
