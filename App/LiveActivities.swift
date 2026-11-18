#if os(iOS)
import ActivityKit
import QuillKit
import UIKit

/// Keeps Quill's sign-in code Live Activities going: it reports the token that lets the
/// push relay start one while the app is closed, and ends each one once its code is stale.
@MainActor
enum LiveActivities {
    static func start() {
        Task {
            for await token in Activity<SignInCodeAttributes>.pushToStartTokenUpdates {
                QuillScene.setActivityStartToken(token.map { String(format: "%02x", $0) }.joined())
            }
        }
        Task {
            for await activity in Activity<SignInCodeAttributes>.activityUpdates {
                expire(activity)
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                Activity<SignInCodeAttributes>.activities.forEach(expire)
            }
        }
        Activity<SignInCodeAttributes>.activities.forEach(expire)
    }

    /// Ends the activity when its code goes stale, or right away if it already has.
    private static func expire(_ activity: Activity<SignInCodeAttributes>) {
        Task {
            if let stale = activity.content.staleDate {
                let wait = stale.timeIntervalSinceNow
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            }
            if activity.content.staleDate != nil {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
