#if os(iOS)
import ActivityKit
import QuillKit
import UIKit

/// Keeps Quill's sign-in code Live Activities going: it reports the token that lets the
/// push relay start one while the app is closed, and ends each one once its code is stale.
enum LiveActivities {
    static func start() {
        Task {
            for await token in Activity<SignInCodeAttributes>.pushToStartTokenUpdates {
                let hex = token.map { String(format: "%02x", $0) }.joined()
                await MainActor.run { QuillScene.setActivityStartToken(hex) }
            }
        }
        Task {
            for await activity in Activity<SignInCodeAttributes>.activityUpdates {
                Task { await expire(activity) }
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { await expireAll() }
        }
        Task { await expireAll() }
    }

    private static func expireAll() async {
        for activity in Activity<SignInCodeAttributes>.activities {
            Task { await expire(activity) }
        }
    }

    /// Ends the activity when its code goes stale, or right away if it already has.
    private static func expire(_ activity: Activity<SignInCodeAttributes>) async {
        guard let stale = activity.content.staleDate else { return }
        let wait = stale.timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
#endif
