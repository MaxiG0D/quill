import SwiftUI

/// The compact layout's home: the current mailbox, with search and Compose at the foot.
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
                BottomSearchBar(isFocused: $isSearchFocused)
            }
            .background {
                LinearGradient(
                    colors: [Palette.background.opacity(0), Palette.background],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
        }
        .navigationTitle(store.title)
        .toolbarTitleDisplayMode(.inline)
        .navigationBarHidden(router.isSearching)
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
            ToolbarItem(placement: .primaryAction) {
                FilterMenu()
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .task {
            await store.load()
        }
    }

    private func showMailboxes() {
        router.isShowingMailboxes = true
    }
}
