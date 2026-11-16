#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension AppIcon {
    /// Makes this the app's icon.
    ///
    /// On iOS the system swaps the Home Screen icon and remembers it. On macOS the Dock
    /// icon changes only while the app runs. `restore()` applies the choice again at launch.
    @MainActor
    func apply() async throws {
        #if canImport(UIKit)
        let application = UIApplication.shared
        guard application.supportsAlternateIcons, application.alternateIconName != alternateName else { return }
        try await application.setAlternateIconName(alternateName)
        #else
        // A nil image returns the Dock to the icon in the app bundle.
        NSApplication.shared.applicationIconImage = alternateName.flatMap { NSImage(named: $0) }
        #endif
    }

    /// Puts the chosen icon back at launch. macOS forgets it between runs, and on iOS
    /// the choice can fall out of step with the system when the default icon changes.
    @MainActor
    static func restore() async {
        try? await stored().apply()
    }
}
