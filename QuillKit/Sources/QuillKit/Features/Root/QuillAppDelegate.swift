#if os(iOS)
import UIKit

/// Receives what the system only tells an app delegate: the device's push token, and
/// pushes that arrive while Quill is running or asleep.
public final class QuillAppDelegate: NSObject, UIApplicationDelegate {
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushDevice.shared.received(deviceToken)
    }

    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        PushDevice.shared.received(nil)
    }

    public func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        let userInfo = UncheckedSendable(userInfo)
        await PushDevice.shared.pushArrived(userInfo.value)
        return .newData
    }
}
#else
import AppKit

/// Receives what the system only tells an app delegate: the device's push token, and
/// pushes that arrive while Quill is running.
public final class QuillAppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        if let path = LaunchOptions().snapshotPath {
            WindowSnapshot.prepare(reportingTo: path)
        }
    }

    public func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushDevice.shared.received(deviceToken)
    }

    public func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        PushDevice.shared.received(nil)
    }

    public func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        let userInfo = UncheckedSendable(userInfo)
        Task {
            await PushDevice.shared.pushArrived(userInfo.value)
        }
    }
}
#endif

/// A push's dictionary is plain property-list data the system hands over once, so it is
/// safe to pass to the main actor.
private struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
