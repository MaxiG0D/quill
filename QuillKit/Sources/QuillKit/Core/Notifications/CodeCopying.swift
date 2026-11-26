import UserNotifications
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Puts a sign-in code on the clipboard from a code alert's Copy action.
enum CodeCopying {
    static let category = "SIGN_IN_CODE"
    static let action = "COPY_CODE"

    /// Has the push relay end this code's Live Activities on every device. The relay may not be
    /// set up yet when the app was just woken, so the handler is given a moment to appear.
    @MainActor
    static func dismissEverywhere(_ code: String) async {
        for _ in 0..<20 {
            if let handler = PushDevice.shared.onCodeCopied {
                await handler(code)
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
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
