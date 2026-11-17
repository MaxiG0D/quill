import SwiftUI

/// The phone layout: the mailbox, with threads pushed on top of it and the
/// mailboxes in a drawer at the leading edge.
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
        .mailboxesDrawer(isPresented: $router.isShowingMailboxes)
        .settingsSheet(isPresented: $router.isShowingSettings)
    }
}
