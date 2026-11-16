import Foundation

#if os(iOS)
import UIKit
#endif

/// Where the system keeps Quill's notification permission.
enum SystemNotificationSettings {
    static var url: URL? {
        #if os(iOS)
        URL(string: UIApplication.openNotificationSettingsURLString)
        #else
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(Bundle.main.bundleIdentifier ?? "")")
        #endif
    }
}
