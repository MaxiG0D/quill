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
    var onPush: (@MainActor (_ threadID: String?) async -> Void)?
    /// The token that lets the relay start a Live Activity while the app is closed (iOS only).
    private(set) var activityStartToken: String?
    /// Run when the activity token arrives or changes, so the relay gets it.
    var onActivityToken: (@MainActor () async -> Void)?
    /// Run when a Live Activity reports its update token (iOS only), so the relay can end it later.
    var onActivityRegistered: (@MainActor (_ activityToken: String, _ code: String) async -> Void)?
    /// Run when a code was copied, so the relay ends its Live Activities everywhere.
    var onCodeCopied: (@MainActor (_ code: String) async -> Void)?
    private var waiters: [CheckedContinuation<String?, Never>] = []
    private var timeoutTask: Task<Void, Never>?

    /// The device's push token, asking the system the first time. Nil when it has none to give
    /// or when the system does not answer in time.
    func token() async -> String? {
        if let knownToken { return knownToken }
        return await withCheckedContinuation { continuation in
            let isFirst = waiters.isEmpty
            waiters.append(continuation)
            guard isFirst else { return }
            timeoutTask?.cancel()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                self?.finishWaiters(returning: self?.knownToken)
            }
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
        finishWaiters(returning: knownToken)
    }

    private func finishWaiters(returning token: String?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let waiting = waiters
        waiters = []
        for continuation in waiting {
            continuation.resume(returning: token)
        }
    }

    func receivedActivityStartToken(_ token: String) async {
        guard token != activityStartToken else { return }
        activityStartToken = token
        await onActivityToken?()
    }

    /// `userInfo` is the push as the system delivered it; its thread ID names the new mail.
    func pushArrived(_ userInfo: [AnyHashable: Any]) async {
        let aps = userInfo["aps"] as? [String: Any]
        await onPush?(aps?["thread-id"] as? String)
    }
}
