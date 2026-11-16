import SwiftUI

/// The wide layout for iPad and Mac: sidebar, thread list and the open thread.
struct SplitRootView: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    @State private var visibility = NavigationSplitViewVisibility.all

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
        .task {
            await store.load()
        }
    }
}
