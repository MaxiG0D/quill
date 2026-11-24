#if os(macOS)
import AppKit
import SwiftUI

/// Makes Quill the app that opens mail links everywhere on the Mac. Turning it off hands them back to Mail.
struct DefaultMailSwitch: View {
    @State private var isDefault = DefaultMailApp.isQuill

    var body: some View {
        HStack {
            Text("Default Mail App")
                .foregroundStyle(Palette.label)
            Spacer(minLength: Spacing.s)
            Toggle("Default Mail App", isOn: Binding(get: { isDefault }, set: change))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Palette.accent)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isDefault = DefaultMailApp.isQuill
        }
    }

    private func change(_ isOn: Bool) {
        isDefault = isOn
        Task {
            await DefaultMailApp.set(isOn)
            isDefault = DefaultMailApp.isQuill
        }
    }
}

/// Which app macOS opens `mailto:` links with.
@MainActor
enum DefaultMailApp {
    private static let probe = URL(string: "mailto:")!

    static var isQuill: Bool {
        guard let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return false }
        return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    /// macOS asks the person to confirm. Declining leaves things as they were.
    static func set(_ quill: Bool) async {
        let app = quill
            ? Bundle.main.bundleURL
            : NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.mail")
        guard let app else { return }
        try? await NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "mailto")
    }
}
#endif
