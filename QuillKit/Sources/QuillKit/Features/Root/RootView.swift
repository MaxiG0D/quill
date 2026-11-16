import SwiftUI

/// Chooses the layout for the space available and hosts what both layouts share:
/// the composer, alerts and haptics.
struct RootView: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(MailNotifier.self) private var notifier: MailNotifier?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var isShowingAlert = false
    private var taps: NotificationTaps { .shared }

    var body: some View {
        @Bindable var router = router
        Group {
            if sizeClass == .compact {
                CompactRootView()
            } else {
                SplitRootView()
            }
        }
        .tint(Palette.accent)
        .sheet(item: $router.draft) { draft in
            ComposeView(draft: draft)
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.surface)
                .composeSheetFrame()
        }
        .alert("Something Went Wrong", isPresented: $isShowingAlert) {
            Button("OK", action: clearAlert)
        } message: {
            Text(store.alert ?? "")
        }
        .onChange(of: store.alert) {
            isShowingAlert = store.alert != nil
        }
        .onChange(of: sizeClass) {
            carrySelectionAcrossLayouts()
        }
        .onChange(of: scenePhase) {
            refreshOnReturn()
        }
        .onChange(of: taps.requestedThreadID, initial: true) {
            openRequestedThread()
        }
        .onChange(of: store.phase) {
            openRequestedThread()
        }
        .task(id: store.badge(for: .mailbox(.inbox))) {
            // Reading or filing mail here changes the badge and clears its notifications.
            await notifier?.reflect(store.threads)
        }
        .task {
            await notifier?.prepare()
        }
        .task(id: store.visibleThreads.first?.id) {
            MessagePreloader.shared.prepare(store.visibleThreads)
        }
        .task {
            await AppIcon.restore()
            await MessageWebView.warmUp()
        }
        .sensoryFeedback(trigger: store.haptic) { _, cue in
            switch cue?.kind {
            case .selection: .selection
            case .lift: .impact(weight: .medium)
            case .success: .success
            case .warning: .warning
            case nil: nil
            }
        }
    }

    /// Catches up on mail that arrived while Quill was in the background.
    private func refreshOnReturn() {
        guard scenePhase == .active, store.phase == .loaded else { return }
        Task {
            await store.refresh(isQuiet: true)
        }
    }

    /// Opens the thread whose notification was tapped, in the Inbox, once the mailbox is loaded.
    private func openRequestedThread() {
        guard store.phase == .loaded, let id = taps.requestedThreadID else { return }
        taps.requestedThreadID = nil
        guard store.thread(id) != nil else { return }
        router.isShowingMailboxes = false
        router.isShowingSettings = false
        store.show(.mailbox(.inbox))
        if sizeClass == .compact {
            router.path = [id]
        } else {
            router.path = []
            store.select(id)
        }
    }

    private func clearAlert() {
        store.alert = nil
    }

    /// Keeps the open thread open when the window crosses between the phone and
    /// wide layouts, as it does when a folding phone opens or an iPad window is resized.
    private func carrySelectionAcrossLayouts() {
        // Settings hangs off a view that belongs to one layout, so it closes with that layout.
        router.isShowingSettings = false
        if sizeClass == .compact {
            router.path = store.selectedThreadID.map { [$0] } ?? []
        } else {
            if let open = router.path.last {
                store.selectedThreadID = open
            }
            router.path = []
            router.isShowingMailboxes = false
        }
    }
}

private extension View {
    /// Sheets size themselves to their content on macOS, so the composer needs a frame there.
    @ViewBuilder
    func composeSheetFrame() -> some View {
        #if os(macOS)
        self.frame(minWidth: 560, idealWidth: 620, minHeight: 520, idealHeight: 600)
        #else
        self
        #endif
    }
}

#Preview {
    RootView()
        .environment(MailStore(snapshot: SampleData.snapshot(now: .now)))
        .environment(Router())
}
