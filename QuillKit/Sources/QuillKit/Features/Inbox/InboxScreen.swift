import SwiftUI

/// The compact layout's home: the current mailbox with Compose at the foot,
/// and search a tap away in the toolbar.
struct InboxScreen: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    @FocusState private var isSearchFocused: Bool
    @State private var isTitleCovered = false

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
                } else {
                    ComposeButton(action: compose)
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
        .navigationTitle(store.title)
        .toolbarTitleDisplayMode(.inline)
        .hidesNavigationBar(router.isSearching)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: showMailboxes) {
                    MonogramAvatar(store.account, size: .compact)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Mailboxes")
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .principal) {
                Text(store.title)
                    .textRole(.section)
                    .opacity(isTitleCovered ? 1 : 0)
                    .animation(Motion.quick, value: isTitleCovered)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Search", systemImage: "magnifyingglass", action: beginSearch)
                    .tint(Palette.accent)
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
