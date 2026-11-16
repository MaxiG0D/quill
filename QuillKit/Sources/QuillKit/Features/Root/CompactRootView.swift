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
        .sheet(isPresented: $router.isShowingMailboxes) {
            MailboxesSheet()
        }
    }
}
