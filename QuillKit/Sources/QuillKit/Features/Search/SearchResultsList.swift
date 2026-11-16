import SwiftUI

/// Search results for the compact layout, with matches marked in each row.
struct SearchResultsList: View {
    @Environment(MailStore.self) private var store

    var body: some View {
        List {
            MailboxTitle(title: "Search")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.xl, leading: Spacing.xxs, bottom: Spacing.xxs, trailing: 0))

            if !store.searchResults.isEmpty || store.isSearching {
                Section {
                    ForEach(store.searchResults) { result in
                        NavigationLink(value: result.id) {
                            MailRow(thread: result.thread, query: store.searchQuery, excerpt: result.excerpt)
                        }
                        .hidesNavigationLinkIndicator()
                        .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.m, bottom: Spacing.s, trailing: Spacing.m))
                        .contextMenu {
                            ThreadActions(thread: result.thread)
                        }
                    }
                    if store.isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: Metrics.target)
                            .listRowSeparator(.hidden, edges: .bottom)
                    }
                }
                .listRowBackground(Palette.surface)
                .listRowSeparatorTint(Palette.separator)
            }
        }
        .cardListStyle()
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if hasNoResults {
                InboxZero()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(Motion.list, value: store.searchResults)
        .animation(Motion.quick, value: store.isSearching)
    }

    private var hasNoResults: Bool {
        !store.searchQuery.isEmpty && store.searchResults.isEmpty && !store.isSearching
    }
}
