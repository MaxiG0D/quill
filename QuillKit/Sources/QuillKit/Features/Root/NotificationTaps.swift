import Observation
import UserNotifications

/// Hears about taps on Quill's notifications and holds the thread to open until the
/// mailbox is on screen, which on a cold launch is a moment after the tap.
@MainActor
@Observable
final class NotificationTaps: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationTaps()

    /// The thread whose notification was tapped. `RootView` opens it and clears this.
    var requestedThreadID: MailThread.ID?

    /// Starts listening. The system only reports the tap that launched the app to a
    /// listener that is in place before launch finishes.
    func listen() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// The completion handler form: UIKit expects `completionHandler` on the main thread,
    /// and the async form finishes on a background one and crashes.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let content = response.notification.request.content
        let threadID = content.threadIdentifier
        let code = content.userInfo["code"] as? String
        let isCopy = response.actionIdentifier == CodeCopying.action
        Task { @MainActor in
            if isCopy, let code {
                CodeCopying.copy(code)
            } else {
                request(threadID)
            }
            completionHandler()
        }
    }

    /// A sign-in code is worth a banner even while Quill is open, since the person is most
    /// likely waiting on it. Other mail is already on screen.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        let hasCode = notification.request.content.userInfo["code"] is String
        completionHandler(hasCode ? [.banner, .sound] : [])
    }

    private func request(_ threadID: MailThread.ID) {
        requestedThreadID = threadID.isEmpty ? nil : threadID
    }
}
