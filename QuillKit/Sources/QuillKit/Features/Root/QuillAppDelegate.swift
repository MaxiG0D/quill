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
        await PushDevice.shared.pushArrived()
        return .newData
    }
}
#else
import AppKit

/// Receives what the system only tells an app delegate: the device's push token, and
/// pushes that arrive while Quill is running.
public final class QuillAppDelegate: NSObject, NSApplicationDelegate {
    public func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushDevice.shared.received(deviceToken)
    }

    public func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        PushDevice.shared.received(nil)
    }

    public func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        Task {
            await PushDevice.shared.pushArrived()
        }
    }
}
#endif
