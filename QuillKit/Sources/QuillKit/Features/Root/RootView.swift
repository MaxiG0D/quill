import SwiftUI

/// Chooses the layout for the space available and hosts what both layouts share:
/// the composer, alerts and haptics.
struct RootView: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var isShowingAlert = false

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
        .task {
            await AppIcon.restore()
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
