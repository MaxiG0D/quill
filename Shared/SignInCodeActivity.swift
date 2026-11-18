#if os(iOS)
import ActivityKit
import AppIntents
import UIKit

/// The Live Activity that shows a sign-in code on the Lock Screen and in the Dynamic Island.
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

/// The Copy button. It runs in the app, copies the code, and ends the activity.
struct CopyCodeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Copy"

    @Parameter(title: "Code") var code: String

    init() {}

    init(code: String) {
        self.code = code
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        UIPasteboard.general.string = code
        for activity in Activity<SignInCodeAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
#endif
