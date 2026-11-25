import SwiftUI

/// The middle column of the wide layout: the current mailbox, or search results.
struct ThreadColumn: View {
    @Environment(MailStore.self) private var store

    @FocusState private var isFocused: Bool
    @State private var isConfirmingEmptyTrash = false
    #if !os(macOS)
    @State private var topSafeArea = 0.0
    /// Whether the list starts at the screen's leading edge, under the account's picture.
    @State private var isAtLeadingEdge = false
    #endif

    var body: some View {
        ScrollViewReader { proxy in
            container {
                #if !os(macOS)
                HStack(alignment: .firstTextBaseline) {
                    MailboxTitle(title: isSearching ? "Search" : store.title, count: isSearching ? 0 : store.headerCount)
                    Spacer(minLength: Spacing.xs)
                    if !isSearching {
                        Button(store.isSelecting ? "Done" : "Select", systemImage: store.isSelecting ? "checkmark.circle.fill" : "checkmark.circle") {
                            withAnimation(Motion.quick) {
                                if store.isSelecting {
                                    store.clearSelection()
                                } else {
                                    store.isSelecting = true
                                }
                            }
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Palette.accent)
                        .buttonStyle(.plain)
                        .padding(.trailing, Spacing.xs)
                        FilterMenu()
                    }
                }
                .padding(.horizontal, Spacing.s)
                .padding(.bottom, Spacing.xs)
                .plainColumnRow()
                #endif
                if !isSearching && store.isInbox && !store.inboxCategories.isEmpty {
                    CategoryTabs()
                        .padding(.horizontal, Spacing.s)
                        .padding(.bottom, Spacing.xs)
                        .plainColumnRow()
                }
                if isSearching {
                    searchFilterChips
                        .padding(.horizontal, Spacing.s)
                        .padding(.bottom, Spacing.xs)
                        .plainColumnRow()
                }
                if !isSearching && store.filter != .all {
                    activeFilterChip
                        .padding(.horizontal, Spacing.s)
                        .padding(.bottom, Spacing.xs)
                        .plainColumnRow()
                }
                if !isSearching && store.selection == .mailbox(.trash) && !store.sections.isEmpty {
                    emptyTrashBar
                        .padding(.horizontal, Spacing.s)
                        .padding(.bottom, Spacing.xs)
                        .plainColumnRow()
                }
                if isSearching {
                    results
                } else {
                    mailbox
                }
            }
            .onChange(of: store.selectedThreadID) { _, id in
                guard let id else { return }
                withAnimation(Motion.quick) {
                    proxy.scrollTo(id)
                }
            }
        }
        .background(Palette.background)
        .overlay {
            if case .failed = store.phase, !isSearching {
                LoadFailedView()
                    .transition(.opacity)
            } else if isLoadingEmpty {
                MailLoadingIndicator()
            } else if isEmpty {
                emptyView
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if store.isSelecting || !store.selectedThreadIDs.isEmpty {
                BulkActionBar()
                    .padding(.horizontal, Spacing.s)
                    .padding(.bottom, bulkBarBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.list, value: store.isSelecting || !store.selectedThreadIDs.isEmpty)
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
        .confirmationDialog(
            "Empty Trash?",
            isPresented: $isConfirmingEmptyTrash,
            titleVisibility: .visible
        ) {
            Button("Empty Trash", role: .destructive) {
                withAnimation(Motion.list) { store.emptyTrash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Messages in Trash will be permanently deleted.")
        }
        .navigationTitle("")
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                MailboxTitle(title: isSearching ? "Search" : store.title, count: isSearching ? 0 : store.headerCount)
                    .padding(.leading, Spacing.xs)
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItemGroup(placement: .automatic) {
                if !isSearching {
                    Button(store.isSelecting ? "Done" : "Select", systemImage: store.isSelecting ? "checkmark.circle.fill" : "checkmark.circle") {
                        withAnimation(Motion.quick) {
                            if store.isSelecting {
                                store.clearSelection()
                            } else {
                                store.isSelecting = true
                            }
                        }
                    }
                    .help(store.isSelecting ? "Finish selecting" : "Select multiple messages")
                    FilterMenu()
                        .help("Filter messages")
                }
            }
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

    private var bulkBarBottomPadding: Double {
        #if os(iOS)
        BottomRow.height + Spacing.xl
        #else
        Spacing.m
        #endif
    }

    private var searchFilterChips: some View {
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
                        .background(isOn ? Palette.accentFill : Palette.fill, in: .capsule)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private var emptyTrashBar: some View {
        Button(role: .destructive) {
            isConfirmingEmptyTrash = true
        } label: {
            Label("Empty Trash", systemImage: "trash.slash")
                .textRole(.chip)
                .foregroundStyle(Palette.destructive)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs + 2)
                .background(Palette.destructive.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.pressable)
        .help("Permanently delete all messages in Trash")
    }

    private var activeFilterChip: some View {
        Button {
            withAnimation(Motion.list) { store.filter = .all }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: store.filter.symbol)
                    .font(.caption.weight(.semibold))
                Text(store.filter.title)
                    .textRole(.chip)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xxs + 1)
            .background(Palette.accentTint, in: .capsule)
        }
        .buttonStyle(.pressable)
        .help("Clear filter")
        .accessibilityLabel("Clear \(store.filter.title) filter")
    }

    @ViewBuilder
    private var emptyView: some View {
        if isSearching {
            InboxZero(size: 130, message: "No Results", accessibilityTitle: "No search results")
                .allowsHitTesting(false)
        } else if store.filter != .all {
            VStack(spacing: Spacing.s) {
                Text("No \(store.filter.title.lowercased()) mail")
                    .textRole(.section)
                    .foregroundStyle(Palette.secondaryLabel)
                Button("Show All") {
                    withAnimation(Motion.list) { store.filter = .all }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            InboxZero(size: 150)
                .allowsHitTesting(false)
        }
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
        .closesSwipeRowsOnScroll()
        .scrollDismissesKeyboard(.immediately)
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
            EmptyView()
        case .loaded:
            ForEach(store.sections) { section in
                SectionHeader(kind: section.kind)
                    .padding(.horizontal, Spacing.s)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xxs)
                    .plainColumnRow()
                ForEach(section.threads) { thread in
                    ThreadColumnRow(thread: thread, onFocus: focusList)
                        .id(thread.id)
                }
            }
            if store.hasMoreThreads {
                Button {
                    Task { await store.loadMore() }
                } label: {
                    Group {
                        if store.isLoadingMore {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Load More")
                                .textRole(.meta)
                                .fontWeight(.semibold)
                                .foregroundStyle(Palette.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: Metrics.target)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(store.isLoadingMore)
                .plainColumnRow()
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        ForEach(store.searchResults) { result in
            ThreadColumnRow(thread: result.thread, query: store.searchQuery, excerpt: result.excerpt, onFocus: focusList)
                .id(result.id)
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
        store.hasSearchQuery || store.searchFilter != .all
    }

    private var isEmpty: Bool {
        if isSearching {
            store.searchResults.isEmpty && !store.isSearching
        } else {
            store.isSettled && store.sections.isEmpty
        }
    }

    private var isLoadingEmpty: Bool {
        !isSearching && !store.isSettled && store.sections.isEmpty
    }

    private func focusList() {
        isFocused = true
    }

    private func step(_ offset: Int) -> KeyPress.Result {
        store.selectNeighbor(offset: offset)
        return .handled
    }
}
