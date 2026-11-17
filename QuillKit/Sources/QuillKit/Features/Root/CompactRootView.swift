import SwiftUI

/// The phone layout: the mailbox, with threads pushed on top of it.
struct CompactRootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            InboxScreen()
                .navigationDestination(for: MailThread.ID.self) { id in
                    ThreadScreen(threadID: id)
                }
        }
        .overlay {
            drawer
        }
    }

    /// Mailboxes slide in from the leading edge, the way the sidebar does in the wide layout.
    @ViewBuilder
    private var drawer: some View {
        ZStack(alignment: .leading) {
            if router.isShowingMailboxes {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .accessibilityHidden(true)
                    .transition(.opacity)
                MailboxesSheet()
                    .frame(maxWidth: 360)
                    .background {
                        UnevenRoundedRectangle(bottomTrailingRadius: Radius.large, topTrailingRadius: Radius.large)
                            .fill(Palette.background)
                            .shadow(color: .black.opacity(0.18), radius: 16, x: 4)
                            .ignoresSafeArea()
                    }
                    .transition(.move(edge: .leading))
                    .gesture(
                        DragGesture().onEnded { drag in
                            if drag.translation.width < -60 { close() }
                        }
                    )
            }
        }
        .animation(Motion.scene, value: router.isShowingMailboxes)
    }

    private func close() {
        router.isShowingMailboxes = false
    }
}
