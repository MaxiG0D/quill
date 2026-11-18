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
                let id = activity.id
                Task { await expire(id: id) }
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
        #if DEBUG
        Task { @MainActor in
            LiveActivityTest.start = { startTest() }
        }
        #endif
    }

    #if DEBUG
    /// Starts an activity straight from the app, to tell the widget apart from the push.
    @MainActor
    private static func startTest() -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return "Live Activities are off for Quill." }
        let state = SignInCodeAttributes.ContentState(sender: "Quill", code: "482913", display: "482 913")
        do {
            _ = try Activity.request(
                attributes: SignInCodeAttributes(),
                content: .init(state: state, staleDate: .now.addingTimeInterval(600))
            )
            return nil
        } catch {
            return String(describing: error)
        }
    }
    #endif

    private static func expireAll() async {
        for id in Activity<SignInCodeAttributes>.activities.map(\.id) {
            Task { await expire(id: id) }
        }
    }

    /// Ends the activity when its code goes stale, or right away if it already has.
    private static func expire(id: String) async {
        guard let activity = Activity<SignInCodeAttributes>.activities.first(where: { $0.id == id }),
              let stale = activity.content.staleDate else { return }
        let wait = stale.timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
#endif
