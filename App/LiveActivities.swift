#if os(iOS)
import ActivityKit
import QuillKit
import UIKit

/// Keeps Quill's sign-in code Live Activities going: it reports the token that lets the
/// push relay start one while the app is closed, and ends each one once its code is stale.
enum LiveActivities {
    /// Debug builds keep a short trail of what Live Activities did, for the Test Code row to show.
    private static func note(_ line: String) {
        #if DEBUG
        let key = "liveActivityTrace"
        var trail = UserDefaults.standard.stringArray(forKey: key) ?? []
        trail.append("\(Date.now.formatted(date: .omitted, time: .standard)) \(line)")
        UserDefaults.standard.set(Array(trail.suffix(6)), forKey: key)
        #endif
    }

    static func start() {
        Task {
            for await token in Activity<SignInCodeAttributes>.pushToStartTokenUpdates {
                let hex = token.map { String(format: "%02x", $0) }.joined()
                note("start token \(hex.count / 2) bytes")
                await MainActor.run { QuillScene.setActivityStartToken(hex) }
            }
        }
        Task {
            for await activity in Activity<SignInCodeAttributes>.activityUpdates {
                let id = activity.id
                note("activity \(id.prefix(6)) appeared")
                Task { await announce(id: id) }
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
        note("launched, enabled: \(ActivityAuthorizationInfo().areActivitiesEnabled)")
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
        let state = SignInCodeAttributes.ContentState(sender: "GitHub", code: "482913", display: "482 913")
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

    /// Expands the Dynamic Island for a moment, so a new code is hard to miss.
    private static func announce(id: String) async {
        guard let activity = Activity<SignInCodeAttributes>.activities.first(where: { $0.id == id }) else { return }
        let content = activity.content
        let alert = AlertConfiguration(
            title: "\(content.state.sender)",
            body: "\(content.state.display)",
            sound: .default
        )
        await activity.update(content, alertConfiguration: alert)
        note("expanded \(id.prefix(6))")
    }

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
