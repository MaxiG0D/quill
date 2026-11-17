import SwiftUI

/// The middle column of the wide layout: the current mailbox, or search results.
struct ThreadColumn: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                #if !os(macOS)
                MailboxTitle(title: isSearching ? "Search" : store.title, count: isSearching ? 0 : store.unreadCount)
                    .padding(.horizontal, Spacing.s)
                    .padding(.bottom, Spacing.xs)
                #endif
                if isSearching {
                    results
                } else {
                    mailbox
                }
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.bottom, Metrics.listBottomPadding)
        }
        .background(Palette.background)
        .overlay {
            if isEmpty {
                InboxZero(size: 150)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            SyncProgressBar()
        }
        .animation(Motion.list, value: isEmpty)
        .animation(Motion.list, value: store.sections)
        .refreshable {
            await store.refresh()
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { step(-1) }
        .onKeyPress(.downArrow) { step(1) }
        .navigationTitle("")
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                MailboxTitle(title: isSearching ? "Search" : store.title, count: isSearching ? 0 : store.unreadCount)
                    .padding(.leading, Spacing.xs)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        #else
        .toolbarTitleDisplayMode(.inline)
        // The iPad toolbar has no room for Compose, so it floats over the list as on iPhone.
        .overlay(alignment: .bottomTrailing) {
            ComposeButton(action: compose)
                .padding(Spacing.m)
        }
        #endif
    }

    @ViewBuilder
    private var mailbox: some View {
        switch store.phase {
        case .idle, .loading:
            ForEach(0..<6, id: \.self) { _ in
                SkeletonRow()
                    .padding(Spacing.s)
            }
        case .failed:
            LoadFailedView()
        case .loaded:
            ForEach(store.sections) { section in
                SectionHeader(kind: section.kind)
                    .padding(.horizontal, Spacing.s)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xxs)
                ForEach(section.threads) { thread in
                    ThreadColumnRow(thread: thread)
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        ForEach(store.searchResults) { result in
            ThreadColumnRow(thread: result.thread, query: store.searchQuery, excerpt: result.excerpt)
        }
        if store.isSearching {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: Metrics.target)
        }
    }

    private var isSearching: Bool {
        !store.searchQuery.isEmpty
    }

    private var isEmpty: Bool {
        if isSearching {
            store.searchResults.isEmpty && !store.isSearching
        } else {
            store.isSettled && store.sections.isEmpty
        }
    }

    private func compose() {
        router.draft = Draft()
    }

    private func step(_ offset: Int) -> KeyPress.Result {
        store.selectNeighbor(offset: offset)
        return .handled
    }
}
