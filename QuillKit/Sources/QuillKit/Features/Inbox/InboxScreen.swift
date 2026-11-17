import SwiftUI

/// The compact layout's home: the current mailbox, with Search and Compose at the
/// bottom trailing corner. When the device leaves a strip beside the content, as the
/// folded iPhone Duo does, the two stack inside it and stay clear of the list.
struct InboxScreen: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    @FocusState private var isSearchFocused: Bool
    @State private var isTitleCovered = false
    @State private var trailingInset = 0.0

    /// The narrowest side strip that can hold the actions.
    private static let railMinimum = 56.0

    var body: some View {
        ZStack {
            if router.isSearching {
                SearchResultsList()
                    .transition(.opacity)
            } else {
                ThreadList(isTitleCovered: $isTitleCovered)
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
                if router.isSearching {
                    BottomSearchBar(isFocused: $isSearchFocused)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !hasRail {
                    InboxActions(search: beginSearch, compose: compose)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.xs)
                        .transition(.scale(scale: 0.6, anchor: .trailing).combined(with: .opacity))
                }
            }
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
        .navigationTitle(store.title)
        .toolbarTitleDisplayMode(.inline)
        .hidesNavigationBar(router.isSearching)
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
                .opacity(isTitleCovered ? 1 : 0)
                .allowsHitTesting(isTitleCovered)
                .animation(Motion.quick, value: isTitleCovered)
            }
            ToolbarItem(placement: .primaryAction) {
                FilterMenu()
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .onChange(of: router.isSearching) { _, searching in
            guard searching else { return }
            // The field joins the hierarchy in this update, so focus it on the next turn.
            Task { isSearchFocused = true }
        }
        .task {
            await store.load()
        }
    }

    private var hasRail: Bool {
        trailingInset >= Self.railMinimum
    }

    private func beginSearch() {
        withAnimation(Motion.scene) { router.isSearching = true }
    }

    private func compose() {
        router.draft = Draft()
    }

    private func showMailboxes() {
        router.isShowingMailboxes = true
    }
}
