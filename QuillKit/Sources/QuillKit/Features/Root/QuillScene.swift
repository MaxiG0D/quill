import SwiftUI

/// The app's window and commands. The app target's only job is to show this scene.
public struct QuillScene: Scene {
    @State private var store: MailStore
    @State private var router: Router
    private let options: LaunchOptions

    public init() {
        let options = LaunchOptions()
        self.options = options
        _store = State(initialValue: options.makeStore())
        _router = State(initialValue: options.makeRouter())
    }

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .preferredColorScheme(options.colorScheme)
        }
        #if os(macOS)
        .defaultSize(width: 1334, height: 834)
        .windowToolbarStyle(.unified(showsTitle: false))
        #endif
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Message", action: compose)
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        #if os(macOS)
        Settings {
            SettingsView()
                .tint(Palette.accent)
                .preferredColorScheme(options.colorScheme)
        }
        #endif
    }

    private func compose() {
        router.draft = Draft()
    }
}
