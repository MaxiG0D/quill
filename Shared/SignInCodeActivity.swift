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

/// How the Copy button tells the push relay that a code was copied, so its Live Activity
/// ends on the other devices too. The app sets it when it launches; the widget never runs it.
enum CodeDismissal {
    nonisolated(unsafe) static var send: (@Sendable (String) async -> Void)?
}

/// The Copy button. It runs in the app, copies the code, and ends the activity.
struct CopyCodeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Copy"
    /// iOS drops a clipboard write from an app that is only woken in the background, so Copy
    /// brings Quill to the front for a moment, without changing what it shows.
    static let openAppWhenRun = true

    @Parameter(title: "Code") var code: String

    init() {}

    init(code: String) {
        self.code = code
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        UIPasteboard.general.string = code
        let wrote = UIPasteboard.general.hasStrings && UIPasteboard.general.string == code
        let activities = Activity<SignInCodeAttributes>.activities
        for activity in activities {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
        await CodeDismissal.send?(code)
        #if DEBUG
        var trail = UserDefaults.standard.stringArray(forKey: "liveActivityTrace") ?? []
        trail.append("\(Date.now.formatted(date: .omitted, time: .standard)) copy: ending \(activities.count), wrote \(wrote ? "ok" : "failed")")
        UserDefaults.standard.set(Array(trail.suffix(6)), forKey: "liveActivityTrace")
        #endif
        return .result()
    }
}
#endif
