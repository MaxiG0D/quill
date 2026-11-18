import Foundation

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// This device as Apple's push service knows it. `QuillAppDelegate` reports to it, since
/// the system only tells an app delegate about push tokens and arriving pushes.
@MainActor
final class PushDevice {
    static let shared = PushDevice()

    /// The device's push token in hexadecimal, once the system has given one.
    private(set) var knownToken: String?
    /// Run when a push arrives, so the mailbox is up to date before the person opens it.
    var onPush: (@MainActor () async -> Void)?
    /// The token that lets the relay start a Live Activity while the app is closed (iOS only).
    private(set) var activityStartToken: String?
    /// Run when the activity token arrives or changes, so the relay gets it.
    var onActivityToken: (@MainActor () async -> Void)?
    private var waiters: [CheckedContinuation<String?, Never>] = []

    /// The device's push token, asking the system the first time. Nil when it has none to give.
    func token() async -> String? {
        if let knownToken { return knownToken }
        return await withCheckedContinuation { continuation in
            let isFirst = waiters.isEmpty
            waiters.append(continuation)
            guard isFirst else { return }
            #if os(iOS)
            UIApplication.shared.registerForRemoteNotifications()
            #else
            NSApplication.shared.registerForRemoteNotifications()
            #endif
        }
    }

    /// The system's answer: a token, or nil when registration failed.
    func received(_ token: Data?) {
        knownToken = token?.map { String(format: "%02x", $0) }.joined()
        let waiting = waiters
        waiters = []
        for continuation in waiting {
            continuation.resume(returning: knownToken)
        }
    }

    func receivedActivityStartToken(_ token: String) async {
        guard token != activityStartToken else { return }
        activityStartToken = token
        await onActivityToken?()
    }

    func pushArrived() async {
        await onPush?()
    }
}
