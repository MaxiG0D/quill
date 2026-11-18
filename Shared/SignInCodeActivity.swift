#if os(iOS)
import ActivityKit
import AppIntents

/// The Live Activity that shows a sign-in code on the Lock Screen and in the Dynamic Island.
/// It is for glancing: iOS drops clipboard writes from Live Activity buttons, so Copy lives
/// on the code alert's long-press view (`CodeNotification`). Its only button closes it.
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

/// How closing a code reaches the push relay, so its Live Activity ends on the other devices
/// too. The app sets it when it launches; the widget never runs it.
enum CodeDismissal {
    nonisolated(unsafe) static var send: (@Sendable (String) async -> Void)?
}

/// The ✕ button. It runs in the app and ends the code's activity here and everywhere else.
struct CloseCodeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Close"
    /// Only the Live Activity runs it, so Shortcuts has no business listing it.
    static let isDiscoverable = false

    @Parameter(title: "Code") var code: String

    init() {}

    init(code: String) {
        self.code = code
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        for activity in Activity<SignInCodeAttributes>.activities where activity.content.state.code == code {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        await CodeDismissal.send?(code)
        return .result()
    }
}
#endif
