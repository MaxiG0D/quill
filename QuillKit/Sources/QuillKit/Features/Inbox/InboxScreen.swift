import SwiftUI

/// The compact layout's home: the current mailbox, with the account's picture at the
/// bottom leading corner and Search and Compose at the bottom trailing corner. When the device leaves a strip beside the content, as the
/// folded iPhone Duo does, the two stack inside it and stay clear of the list.
struct InboxScreen: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @FocusState private var isSearchFocused: Bool
    @State private var isTitleCovered = false
    @State private var trailingInset = 0.0
    @State private var topInset = 0.0

    /// The narrowest side strip that can hold the actions.
    private static let railMinimum = 56.0
    /// The height of the bar whose buttons move into the side strip, leaving its band empty.
    private static let emptyBarHeight = 44.0

    var body: some View {
        ZStack {
            if router.isSearching {
                SearchResultsList()
                    .transition(.opacity)
            } else {
                ThreadList(isTitleCovered: $isTitleCovered, topMargin: liftedTopMargin)
                    .transition(.opacity)
            }
        }
        .background {
            HeroBackground(isTinted: store.isInbox && !router.isSearching)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.xs) {
                if let toast = store.toast {
                    UndoToastView(toast: toast)
                        .padding(.horizontal, Spacing.m)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if store.isSelecting || !store.selectedThreadIDs.isEmpty {
                    BulkActionBar()
                        .padding(.horizontal, Spacing.m)
                        .padding(.bottom, Spacing.xs)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if router.isSearching {
                    BottomSearchBar(isFocused: $isSearchFocused)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // The account's picture holds the leading corner; with a side strip,
                    // Search and Compose stand in the strip instead of this row.
                    HStack(alignment: .bottom) {
                        SettingsButton(size: .floating)
                        Spacer(minLength: 0)
                        if !hasRail {
                            InboxActions(search: beginSearch, compose: compose)
                        }
                    }
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.xs)
                    .transition(.opacity)
                }
            }
            .animation(Motion.list, value: store.toast)
            .background {
                if router.isSearching {
                    LinearGradient(
                        colors: [Palette.background.opacity(0), Palette.background],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .ignoresSafeArea()
                }
            }
        }
        .overlay {
            if hasRail && !router.isSearching {
                InboxActions(
                    arrangement: .stack,
                    size: min(54, trailingInset - Spacing.s),
                    search: beginSearch,
                    compose: compose
                )
                .frame(width: trailingInset)
                .padding(.bottom, Spacing.xs)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .ignoresSafeArea(.container, edges: .trailing)
                .transition(.opacity)
            }
        }
        .onGeometryChange(for: Double.self) { proxy in
            proxy.safeAreaInsets.trailing
        } action: { inset in
            trailingInset = inset
        }
        .onGeometryChange(for: Double.self) { proxy in
            proxy.safeAreaInsets.top
        } action: { inset in
            topInset = inset
        }
        .navigationTitle(store.title)
        .toolbarTitleDisplayMode(.inline)
        .hidesNavigationBar(router.isSearching)
        .clearsNavigationBar(isLifted)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                // The same mark that opens the sidebar in the wide layout, and it opens from the same edge.
                Button("Mailboxes", systemImage: "sidebar.leading", action: showMailboxes)
            }
            ToolbarItem(placement: .principal) {
                Button(action: showMailboxes) {
                    Text(store.title)
                        .textRole(.section)
                        .foregroundStyle(Palette.label)
                }
                .buttonStyle(.pressable)
                .opacity(showsBarTitle ? 1 : 0)
                .allowsHitTesting(showsBarTitle)
                .animation(Motion.quick, value: showsBarTitle)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(store.isSelecting ? "Done" : "Select", systemImage: store.isSelecting ? "checkmark.circle.fill" : "checkmark.circle") {
                    withAnimation(Motion.quick) {
                        if store.isSelecting {
                            store.clearSelection()
                        } else {
                            store.isSelecting = true
                        }
                    }
                }
                .tint(Palette.accent)
                FilterMenu()
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .onChange(of: router.isSearching) { _, searching in
            isTitleCovered = false
            guard searching else { return }
            // The field joins the hierarchy in this update, so focus it on the next turn.
            Task { isSearchFocused = true }
        }
        .onChange(of: store.selection) {
            isTitleCovered = false
        }
        .task {
            await store.load()
        }
    }

    private var hasRail: Bool {
        trailingInset >= Self.railMinimum && verticalSizeClass != .compact
    }

    /// With the bar's buttons in the side strip, the mailbox moves up into the band
    /// the bar left empty. The status bar's share of the inset stays clear. A phone on
    /// its side has a strip too, but keeps its buttons in the bar, so it is left alone.
    private var liftedTopMargin: Double? {
        hasRail ? max(Spacing.s, topInset - Self.emptyBarHeight) : nil
    }

    private var isLifted: Bool {
        liftedTopMargin != nil
    }

    /// The small title belongs to a bar with a backdrop. A lifted mailbox scrolls
    /// through a clear band, where the title would sit on top of the mail.
    private var showsBarTitle: Bool {
        isTitleCovered && !isLifted
    }

    private func beginSearch() {
        withAnimation(Motion.scene) { router.isSearching = true }
    }

    private func compose() {
        if router.draft == nil {
            router.draft = Draft()
        }
    }

    private func showMailboxes() {
        router.isShowingMailboxes = true
    }
}
