import SwiftUI

/// The wide layout for iPad and Mac: sidebar, thread list and the open thread.
struct SplitRootView: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    @State private var visibility = Self.restingVisibility(isRoomy: Self.startsRoomy)
    @State private var isRoomy = Self.startsRoomy

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
        } content: {
            ThreadColumn()
                .navigationSplitViewColumnWidth(min: 300, ideal: 365, max: 460)
        } detail: {
            ThreadPane()
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $store.searchQuery, placement: .toolbar, prompt: "Search")
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
        .settingsSheet(isPresented: $router.isShowingSettings)
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

    /// All three columns when they fit, otherwise the list beside the open thread.
    private static func restingVisibility(isRoomy: Bool) -> NavigationSplitViewVisibility {
        isRoomy ? .all : .doubleColumn
    }
}
