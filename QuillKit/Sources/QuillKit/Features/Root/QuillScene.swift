import SwiftUI

/// The app's window and commands. The app target's only job is to show this scene.
public struct QuillScene: Scene {
    @State private var session: AccountSession
    @State private var router: Router
    private let options: LaunchOptions

    /// - Parameter googleClientID: The iOS OAuth client ID from Google Cloud Console.
    ///   Left empty, Quill opens the sample mailbox instead of signing in to Gmail.
    public init(googleClientID: String = "") {
        let options = LaunchOptions()
        self.options = options
        _session = State(initialValue: AccountSession(options: options, googleClientID: googleClientID))
        _router = State(initialValue: options.makeRouter())
    }

    public var body: some Scene {
        WindowGroup {
            SessionView()
                .environment(session)
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
                    .disabled(session.store == nil)
            }
        }
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(session)
                .tint(Palette.accent)
                .preferredColorScheme(options.colorScheme)
        }
        #endif
    }

    private func compose() {
        router.draft = Draft()
    }
}
