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
    @State private var isFindingRequested = false
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
        .onChange(of: store.threads) {
            openRequestedThread()
        }
        .task(id: store.badge(for: .mailbox(.inbox))) {
            // Reading or filing mail here changes the badge and clears its notifications.
            await notifier?.reflect(store.threads)
        }
        .task(id: scenePhase) {
            // The system only shows its prompt to an app that is in front, which Quill
            // may not be yet in the first moment after launch.
            guard scenePhase == .active else { return }
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
            // Mail with an alert waiting is fetched on its own while the full refresh runs.
            async let arrived: Void = store.bringIn(arrived: await NotificationTaps.deliveredThreadIDs())
            await store.refresh(isQuiet: true)
            await arrived
        }
    }

    /// Opens the thread whose notification was tapped, in the Inbox, once the mailbox is loaded.
    /// A new message is not in the mailbox as last seen, so the tap waits for a refresh to bring it.
    private func openRequestedThread() {
        guard store.phase == .loaded, let id = taps.requestedThreadID else { return }
        guard store.thread(id) != nil else {
            findRequestedThread(id)
            return
        }
        taps.requestedThreadID = nil
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

    /// Refreshes until the tapped thread arrives, then gives up quietly.
    private func findRequestedThread(_ id: MailThread.ID) {
        guard !isFindingRequested else { return }
        isFindingRequested = true
        Task {
            await store.bringIn(arrived: [id])
            for _ in 0..<5 where store.thread(id) == nil {
                await store.refresh(isQuiet: true)
                if store.thread(id) == nil {
                    try? await Task.sleep(for: .seconds(1.5))
                }
            }
            isFindingRequested = false
            if store.thread(id) == nil, taps.requestedThreadID == id {
                taps.requestedThreadID = nil
            } else {
                openRequestedThread()
            }
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
