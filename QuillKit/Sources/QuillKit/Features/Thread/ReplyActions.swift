import SwiftUI

/// Reply, Reply All and Forward, for a conversation's toolbar.
struct ReplyActions: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    let thread: MailThread

    var body: some View {
        Button("Reply", systemImage: "arrowshape.turn.up.left", action: reply)
            .labelStyle(.titleAndIcon)
            .fontWeight(.semibold)
        Spacer()
        Button("Reply All", systemImage: "arrowshape.turn.up.left.2", action: replyAll)
        Button("Forward", systemImage: "arrowshape.turn.up.right", action: forward)
    }

    private func reply() {
        router.draft = .reply(to: thread, from: store.account)
    }

    private func replyAll() {
        router.draft = .reply(to: thread, from: store.account, all: true)
    }

    private func forward() {
        router.draft = .forward(thread)
    }
}
