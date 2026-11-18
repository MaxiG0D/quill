#if os(iOS)
import ActivityKit

/// The Live Activity that shows a sign-in code on the Lock Screen and in the Dynamic Island.
/// It is for glancing: iOS drops clipboard writes from Live Activity buttons, so Copy lives
/// on the code alert's long-press view (`CodeNotification`).
/// The push relay starts it, and the name `SignInCodeAttributes` is what it names in the push.
/// This file is part of both the app and its widget extension.
struct SignInCodeAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var sender: String
        /// The code as typed.
        var code: String
        /// The code in groups that are easy to read.
        var display: String
        /// What the email is about, when it says. Optional, so an older push still decodes.
        var subject: String? = nil
        /// When the code stops being worth showing, in seconds since 1970.
        var expiresAt: Double? = nil
    }
}
#endif
