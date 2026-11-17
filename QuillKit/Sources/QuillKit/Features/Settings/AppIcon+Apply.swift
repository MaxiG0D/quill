#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension AppIcon {
    /// Makes this the app's icon.
    ///
    /// On iOS the system swaps the Home Screen icon and remembers it. On macOS the Dock
    /// icon changes only while the app runs, and follows light and dark mode. `restore()` applies the choice again at launch.
    @MainActor
    func apply() async throws {
        #if canImport(UIKit)
        let application = UIApplication.shared
        guard application.supportsAlternateIcons, application.alternateIconName != alternateName else { return }
        try await application.setAlternateIconName(alternateName)
        #else
        DockIcon.shared.show(self)
        #endif
    }

    /// Puts the chosen icon back at launch. macOS forgets it between runs, and on iOS
    /// the choice can fall out of step with the system when the default icon changes.
    @MainActor
    static func restore() async {
        try? await stored().apply()
    }
}

#if canImport(AppKit) && !canImport(UIKit)
/// Keeps the Dock icon in step with the chosen icon and the system appearance.
///
/// The icon in the app bundle can't change with the appearance on macOS, so while the app
/// runs the Dock picture is set from `DockIcon-<Name>` and set again when the appearance changes.
@MainActor
private final class DockIcon {
    static let shared = DockIcon()

    private var icon = AppIcon.primary
    private var observation: NSKeyValueObservation?

    func show(_ icon: AppIcon) {
        self.icon = icon
        if observation == nil {
            observation = NSApplication.shared.observe(\.effectiveAppearance) { _, _ in
                Task { @MainActor in DockIcon.shared.update() }
            }
        }
        update()
    }

    private func update() {
        let name = NSImage.Name("DockIcon-\(icon.assetName)")
        guard let source = Bundle.module.image(forResource: name) else { return }
        let appearance = NSApplication.shared.effectiveAppearance
        NSApplication.shared.applicationIconImage = NSImage(size: source.size, flipped: false) { rect in
            appearance.performAsCurrentDrawingAppearance { source.draw(in: rect) }
            return true
        }
    }
}
#endif
