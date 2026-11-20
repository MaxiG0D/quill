import SwiftUI

/// The wide layout for iPad and Mac: sidebar, thread list and the open thread.
struct SplitRootView: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    @State private var visibility = Self.restingVisibility(isRoomy: Self.startsRoomy)
    @State private var isRoomy = Self.startsRoomy
    #if os(iOS)
    @State private var bottomRow = BottomRow.Placement()
    #endif

    /// The narrowest window that fits all three columns side by side. Below it the
    /// sidebar would slide over the list, as on an unfolded iPhone Duo or an upright iPad.
    private static let threeColumnWidth = 1000.0

    #if os(macOS)
    private static let startsRoomy = true
    #else
    private static let startsRoomy = false
    #endif

    var body: some View {
        @Bindable var store = store
        @Bindable var router = router
        NavigationSplitView(columnVisibility: $visibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 236, max: 300)
                #if !os(macOS)
                // The sidebar button moves to the bottom row, beside Search.
                .toolbar(removing: .sidebarToggle)
                #endif
        } content: {
            ThreadColumn()
                .navigationSplitViewColumnWidth(min: 300, ideal: 365, max: 460)
        } detail: {
            ThreadPane()
        }
        .navigationSplitViewStyle(.balanced)
        #if os(macOS)
        .searchable(text: $store.searchQuery, placement: .toolbar, prompt: "Search")
        #endif
        .onChange(of: store.searchQuery) {
            store.search()
        }
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                UndoToastView(toast: toast)
                    .padding(Spacing.l)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        #if os(iOS)
        // Compose ends the bottom row: level with Search under the list, and in the trailing
        // corner of the screen, under the iPhone Duo's action rail when it has one.
        .bottomRow(alignment: .bottomTrailing, trailing: bottomRow.composeTrailing) {
            ComposeButton(size: BottomRow.height, action: compose)
                .logBottomRowFrame("compose")
        }
        // The account's picture starts the row in the screen's leading corner, over the
        // sidebar when it shows and before the list's Search when it does not.
        .bottomRow(alignment: .bottomLeading) {
            SettingsButton(size: .large)
                .padding(.leading, Spacing.m)
                .logBottomRowFrame("account")
        }
        .environment(\.bottomRowPlacement, bottomRow)
        .background {
            // Measured on a view that ignores the keyboard, so the row's gap stays put while
            // typing; the keyboard itself still lifts the row.
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: BottomRow.Placement.self) { proxy in
                    BottomRow.Placement(
                        bottomInset: proxy.safeAreaInsets.bottom,
                        trailingInset: proxy.safeAreaInsets.trailing
                    )
                } action: { placement in
                    bottomRow = placement
                }
        }
        #endif
        .settingsSheet(isPresented: $router.isShowingSettings)
        .environment(\.toggleSidebar) {
            withAnimation(Motion.scene) {
                visibility = visibility == .all ? .doubleColumn : .all
            }
        }
        #if !os(macOS)
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width >= Self.threeColumnWidth
        } action: { roomy in
            isRoomy = roomy
            visibility = Self.restingVisibility(isRoomy: roomy)
        }
        .onChange(of: store.selection) {
            // A sidebar that slid over the list steps aside once a mailbox is chosen.
            guard !isRoomy else { return }
            withAnimation(Motion.scene) { visibility = .doubleColumn }
        }
        #endif
        .task {
            await store.load()
        }
    }

    private func compose() {
        router.draft = Draft()
    }

    /// All three columns when they fit, otherwise the list beside the open thread.
    private static func restingVisibility(isRoomy: Bool) -> NavigationSplitViewVisibility {
        isRoomy ? .all : .doubleColumn
    }
}

private struct ToggleSidebarKey: EnvironmentKey {
    static let defaultValue: @MainActor () -> Void = {}
}

extension EnvironmentValues {
    /// Slides the sidebar over, or away from, the thread list.
    var toggleSidebar: @MainActor () -> Void {
        get { self[ToggleSidebarKey.self] }
        set { self[ToggleSidebarKey.self] = newValue }
    }
}
