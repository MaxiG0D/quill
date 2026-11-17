import UserNotifications
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Puts a sign-in code on the clipboard, and gives code alerts their Copy action.
enum CodeCopying {
    static let category = "SIGN_IN_CODE"
    static let action = "COPY_CODE"

    /// Tells the system about the Copy action. Called before the app finishes launching,
    /// so alerts that arrive while it is closed already carry the action.
    static func register() {
        let copy = UNNotificationAction(identifier: action, title: "Copy", options: [])
        let category = UNNotificationCategory(identifier: category, actions: [copy], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    @MainActor
    static func copy(_ code: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
    }
}
