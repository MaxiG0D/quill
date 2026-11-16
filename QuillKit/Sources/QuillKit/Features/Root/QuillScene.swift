import SwiftUI

/// The app's window and commands. The app target's only job is to show this scene.
public struct QuillScene: Scene {
    @State private var session: AccountSession
    @State private var router: Router
    private let options: LaunchOptions

    /// - Parameter googleClientID: The iOS OAuth client ID from Google Cloud Console.
    ///   Left empty, Quill opens the sample mailbox instead of signing in to Gmail.
    /// - Parameter pushRelayURL: The push relay's address. Left empty, Quill checks for new mail itself.
    public init(googleClientID: String = "", pushRelayURL: String = "") {
        let options = LaunchOptions()
        self.options = options
        _session = State(initialValue: AccountSession(options: options, googleClientID: googleClientID, pushRelayURL: pushRelayURL))
        _router = State(initialValue: options.makeRouter())
        NotificationTaps.shared.listen()
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
        #if os(iOS)
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) { [session] in
            BackgroundRefresh.schedule()
            await session.checkMail()
        }
        #endif
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(session)
                .environment(session.pictures)
                .tint(Palette.accent)
                .preferredColorScheme(options.colorScheme)
        }
        #endif
    }

    private func compose() {
        router.draft = Draft()
    }
}
