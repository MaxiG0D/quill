import Foundation

/// A signed-in Google account remembered by Quill for quick account switching.
struct AccountRecord: Identifiable, Hashable, Codable, Sendable {
    /// Lowercased email address, or `"default"` before the account's profile has been loaded.
    let id: String
    var name: String
    var email: String
    var photoURL: URL?
    /// The Keychain account identifier that holds this account's OAuth token.
    var keychainAccount: String
    /// The local archive filename for this account.
    var archiveFilename: String

    var contact: Contact {
        Contact(name: name, email: email, tone: .stable(for: email), photoURL: photoURL)
    }
}
