import SwiftUI

/// The middle column of the wide layout: the current mailbox, or search results.
struct ThreadColumn: View {
    @Environment(MailStore.self) private var store

    @FocusState private var isFocused: Bool
    #if !os(macOS)
    @State private var topSafeArea = 0.0
    /// Whether the list starts at the screen's leading edge, under the account's picture.
    @State private var isAtLeadingEdge = false
    #endif

    var body: some View {
        container {
            #if !os(macOS)
            MailboxTitle(title: isSearching ? "Search" : store.title, count: isSearching ? 0 : store.unreadCount)
                .padding(.horizontal, Spacing.s)
                .padding(.bottom, Spacing.xs)
                .plainColumnRow()
            #endif
            if isSearching {
                results
            } else {
                mailbox
            }
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
                .padding(.leading, isAtLeadingEdge ? BottomRow.height + Spacing.xs : 0)
                .animation(Motion.scene, value: isAtLeadingEdge)
        }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .global).minX < 1
        } action: { atEdge in
            isAtLeadingEdge = atEdge
        }
        #endif
    }

    /// A List on iOS, for the same system swipe actions and row removal as the iPhone's list; the
    /// Mac keeps its plain scroll view.
    @ViewBuilder
    private func container<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        #if os(macOS)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                content()
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.bottom, Metrics.listBottomPadding)
        }
        #else
        List {
            content()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.bottom, Metrics.listBottomPadding, for: .scrollContent)
        #endif
    }

    @ViewBuilder
    private var mailbox: some View {
        switch store.phase {
        case .idle, .loading:
            ForEach(0..<6, id: \.self) { _ in
                SkeletonRow()
                    .padding(Spacing.s)
                    .plainColumnRow()
            }
        case .failed:
            LoadFailedView()
                .plainColumnRow()
        case .loaded:
            ForEach(store.sections) { section in
                SectionHeader(kind: section.kind)
                    .padding(.horizontal, Spacing.s)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xxs)
                    .plainColumnRow()
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
                .plainColumnRow()
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
