import SwiftUI

/// The app's window and commands. The app target's only job is to show this scene.
public struct QuillScene: Scene {
    @State private var session: AccountSession
    private let options: LaunchOptions

    /// - Parameter googleClientID: The iOS OAuth client ID from Google Cloud Console.
    ///   Left empty, Quill opens the sample mailbox instead of signing in to Gmail.
    /// - Parameter pushRelayURL: The push relay's address. Left empty, Quill checks for new mail itself.
    public init(googleClientID: String = "", pushRelayURL: String = "") {
        let options = LaunchOptions()
        self.options = options
        let session = AccountSession(options: options, googleClientID: googleClientID, pushRelayURL: pushRelayURL)
        _session = State(initialValue: session)
        NotificationTaps.shared.listen()
        NotificationActions.register { threadID, mailbox in
            await session.file(threadID, in: mailbox)
        }
    }

    /// Hands over the token that lets the push relay start a Live Activity while Quill is closed.
    @MainActor
    public static func setActivityStartToken(_ token: String) {
        Task {
            await PushDevice.shared.receivedActivityStartToken(token)
        }
    }

    /// Reports a Live Activity's update token, so a Copy on another device can end it.
    @MainActor
    public static func registerActivity(token: String, code: String) async {
        for _ in 0..<20 {
            if let handler = PushDevice.shared.onActivityRegistered {
                await handler(token, code)
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    /// A sign-in code was copied: ends its Live Activities on every device. Failures are silent.
    @MainActor
    public static func dismissCode(_ code: String) async {
        await CodeCopying.dismissEverywhere(code)
    }

    public var body: some Scene {
        WindowGroup {
            QuillWindow(session: session, options: options)
        }
        #if os(macOS)
        .defaultSize(width: 1334, height: 834)
        .windowToolbarStyle(.unified(showsTitle: false))
        #endif
        .commands {
            QuillCommands(session: session)
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
}

/// Gives each window its own navigation and sheet `Router` so multiple windows stay independent.
private struct QuillWindow: View {
    let session: AccountSession
    let options: LaunchOptions
    @State private var router: Router

    init(session: AccountSession, options: LaunchOptions) {
        self.session = session
        self.options = options
        _router = State(initialValue: options.makeRouter())
    }

    var body: some View {
        SessionView()
            .environment(session)
            .environment(router)
            .focusedSceneValue(\.quillRouter, router)
            .preferredColorScheme(options.colorScheme)
            .onOpenURL(perform: open)
            #if os(macOS)
            // A mailto link opens in the window already on screen instead of a new one.
            .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
            #endif
    }

    /// Mail links from other apps, when Quill is the default mail app, start a new message.
    private func open(_ url: URL) {
        guard let draft = Draft(mailto: url) else { return }
        router.compose(draft)
    }
}

private struct QuillCommands: Commands {
    let session: AccountSession
    @FocusedValue(\.quillRouter) private var router

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Message", action: compose)
                .keyboardShortcut("n", modifiers: .command)
                .disabled(session.store == nil || router == nil)
            Button("Check for New Mail", action: refresh)
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(session.store == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("Print…", action: printSelected)
                .keyboardShortcut("p", modifiers: .command)
                .disabled(selectedThread == nil)
        }
        CommandGroup(replacing: .undoRedo) {
            Button(session.store?.toast.map { "Undo \($0.title)" } ?? "Undo", action: undo)
                .keyboardShortcut("z", modifiers: .command)
                .disabled(session.store?.toast == nil)
        }
        CommandMenu("Message") {
            Button(selectedThread?.isUnread == true ? "Mark as Read" : "Mark as Unread", action: toggleUnread)
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(selectedThread == nil)
            Button("Mark All as Read", action: markAllRead)
                .disabled((session.store?.unreadCount ?? 0) == 0)
            Divider()
            Button(selectedThread?.isStarred == true ? "Remove Star" : "Star", action: toggleStar)
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(selectedThread == nil)
            Button(selectedThread?.isPinned == true ? "Unpin" : "Pin", action: togglePin)
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(selectedThread == nil)
        }
    }

    private var selectedThread: MailThread? {
        guard let store = session.store else { return nil }
        return store.thread(store.selectedThreadID ?? router?.path.last)
    }

    private func compose() {
        guard let router, router.draft == nil else { return }
        router.draft = Draft()
    }

    private func refresh() {
        guard let store = session.store else { return }
        Task { await store.refresh() }
    }

    private func undo() {
        guard let store = session.store else { return }
        withAnimation(Motion.list) { store.undo() }
    }

    private func toggleUnread() {
        guard let store = session.store, let id = selectedThread?.id else { return }
        withAnimation(Motion.quick) { store.toggleUnread(id) }
    }

    private func markAllRead() {
        guard let store = session.store else { return }
        withAnimation(Motion.quick) { store.markAllRead() }
    }

    private func toggleStar() {
        guard let store = session.store, let id = selectedThread?.id else { return }
        withAnimation(Motion.quick) { store.toggleStar(id) }
    }

    private func togglePin() {
        guard let store = session.store, let id = selectedThread?.id else { return }
        withAnimation(Motion.list) { store.togglePin(id) }
    }

    private func printSelected() {
        guard let store = session.store, let thread = selectedThread else { return }
        ThreadPrinter.shared.printThread(thread, timestamp: store.timestamp)
    }
}

private struct QuillRouterKey: FocusedValueKey {
    typealias Value = Router
}

private extension FocusedValues {
    var quillRouter: Router? {
        get { self[QuillRouterKey.self] }
        set { self[QuillRouterKey.self] = newValue }
    }
}
