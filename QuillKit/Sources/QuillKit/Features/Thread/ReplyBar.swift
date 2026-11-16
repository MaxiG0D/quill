import SwiftUI

/// The bar pinned under a conversation: Reply, then Reply All and Forward.
struct ReplyBar: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    let thread: MailThread

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Button(action: reply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
                    .font(.headline)
                    .foregroundStyle(Palette.onFill)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Palette.accentFill, in: .capsule)
            }
            .buttonStyle(.pressable)

            Group {
                IconButton("Reply All", systemImage: "arrowshape.turn.up.left.2", width: 52, height: 50, action: replyAll)
                IconButton("Forward", systemImage: "arrowshape.turn.up.right", width: 52, height: 50, action: forward)
            }
            .font(.title3)
            .foregroundStyle(Palette.accent)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Palette.surface)
        .overlay(alignment: .top) {
            Palette.separator.frame(height: Metrics.hairline)
        }
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
