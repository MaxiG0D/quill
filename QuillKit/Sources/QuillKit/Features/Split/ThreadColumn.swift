import SwiftUI

/// The middle column of the wide layout: the current mailbox, or search results.
struct ThreadColumn: View {
    @Environment(MailStore.self) private var store

    @FocusState private var isFocused: Bool
    /// The row whose swipe buttons are showing.
    @State private var openRowID: MailThread.ID?
    #if !os(macOS)
    @State private var topSafeArea = 0.0
    #endif

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
        // This column only lives inside the split view, and the split view hands its columns a
        // compact width class even on a wide screen, so nothing here is gated on size class.
        // The title is drawn in the list itself, so the column keeps no navigation bar: the
        // serif title rises to the top, with the rows scrolling up under a soft edge.
        .toolbarVisibility(.hidden, for: .navigationBar)
        .contentMargins(.top, topMargin, for: .scrollContent)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onGeometryChange(for: Double.self) { proxy in
            proxy.safeAreaInsets.top
        } action: { inset in
            topSafeArea = inset
        }
        // The sidebar button and Search share one line with Compose; see BottomRow.
        .bottomRow(alignment: .bottom) {
            SplitSearchRow()
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
                    ThreadColumnRow(thread: thread, openID: $openRowID)
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        ForEach(store.searchResults) { result in
            ThreadColumnRow(thread: result.thread, openID: $openRowID, query: store.searchQuery, excerpt: result.excerpt)
        }
        if store.isSearching {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: Metrics.target)
        }
    }

    #if !os(macOS)
    /// The title's distance from the top edge of the screen at scroll start.
    private static let titleTop = Spacing.xl

    /// Tops up the safe area to the title's resting distance, so the title lands at the same
    /// height whether the status bar sits above the list (iPad) or off to the side (iPhone Duo).
    private var topMargin: Double {
        max(Self.titleTop - topSafeArea, Spacing.xxs)
    }
    #endif

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

    private func step(_ offset: Int) -> KeyPress.Result {
        store.selectNeighbor(offset: offset)
        return .handled
    }
}
