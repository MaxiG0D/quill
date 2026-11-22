import SwiftUI

/// Search results for the compact layout, with quick filter chips, recent searches, and highlighted matches.
struct SearchResultsList: View {
    @Environment(MailStore.self) private var store

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: Spacing.s) {
                MailboxTitle(title: "Search")
                filterChips
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Spacing.xl, leading: Spacing.xxs, bottom: Spacing.xxs, trailing: 0))

            if !store.hasSearchQuery && store.searchFilter == .all && !store.recentSearches.isEmpty {
                Section {
                    ForEach(store.recentSearches, id: \.self) { recent in
                        Button {
                            store.searchQuery = recent
                            store.search()
                        } label: {
                            HStack(spacing: Spacing.s) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(Palette.secondaryLabel)
                                Text(recent)
                                    .foregroundStyle(Palette.label)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Recent")
                            .textRole(.section)
                            .foregroundStyle(Palette.label)
                        Spacer()
                        Button("Clear") {
                            withAnimation(Motion.quick) { store.clearRecentSearches() }
                        }
                        .textRole(.meta)
                        .foregroundStyle(Palette.accent)
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.xxs, bottom: Spacing.xs, trailing: Spacing.xxs))
                }
                .listRowBackground(Palette.surface)
                .listRowSeparatorTint(Palette.separator)
            }

            if !store.searchResults.isEmpty || store.isSearching {
                Section {
                    ForEach(store.searchResults) { result in
                        NavigationLink(value: result.id) {
                            MailRow(thread: result.thread, query: store.searchQuery, excerpt: result.excerpt)
                        }
                        .hidesNavigationLinkIndicator()
                        .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.m, bottom: Spacing.s, trailing: Spacing.m))
                        .threadSwipeActions(result.thread)
                        .contextMenu {
                            ThreadActions(thread: result.thread)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            if store.hasSearchQuery {
                                store.recordSearch(store.searchQuery)
                            }
                        })
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
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if hasNoResults {
                InboxZero(size: 180, message: "No Results", accessibilityTitle: "No search results")
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(Motion.list, value: store.searchResults)
        .animation(Motion.quick, value: store.isSearching)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(InboxFilter.allCases.filter { $0 != .all }) { filter in
                    let isOn = store.searchFilter == filter
                    Button {
                        withAnimation(Motion.quick) {
                            store.setSearchFilter(isOn ? .all : filter)
                        }
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: filter.symbol)
                                .font(.caption2.weight(.semibold))
                            Text(filter.title)
                                .textRole(.chip)
                        }
                        .foregroundStyle(isOn ? Palette.onFill : Palette.secondaryLabel)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xxs + 1)
                        .background(isOn ? Palette.accentFill : Palette.surface, in: .capsule)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private var hasNoResults: Bool {
        (store.hasSearchQuery || store.searchFilter != .all) && store.searchResults.isEmpty && !store.isSearching
    }
}
