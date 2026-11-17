import SwiftUI

/// The wide layout's toolbar: a triage group with Archive, Move and Delete, and a respond group.
struct SplitToolbar: ToolbarContent {
    let thread: MailThread?
    let store: MailStore
    let router: Router

    var body: some ToolbarContent {
        ToolbarItemGroup {
            Button("Archive", systemImage: "archivebox", action: archive)
                .keyboardShortcut("e", modifiers: .command)
            MoveMenu(thread: thread)
            Button("Delete", systemImage: "trash", action: trash)
                .tint(Palette.destructive)
                .keyboardShortcut(.delete, modifiers: .command)
            Menu("More", systemImage: "ellipsis") {
                if let thread {
                    ThreadActions(thread: thread, hasMenus: false, hasTriage: false)
                    LabelMenu(thread: thread)
                }
            }
        }
        ToolbarSpacer(.fixed)
        ToolbarItemGroup {
            Button("Reply", systemImage: "arrowshape.turn.up.left", action: reply)
                .keyboardShortcut("r", modifiers: .command)
            Button("Reply All", systemImage: "arrowshape.turn.up.left.2", action: replyAll)
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Forward", systemImage: "arrowshape.turn.up.right", action: forward)
                .keyboardShortcut("f", modifiers: [.command, .shift])
        }
    }

    private func archive() {
        guard let thread else { return }
        withAnimation(Motion.list) { store.archive(thread.id) }
    }

    private func trash() {
        guard let thread else { return }
        withAnimation(Motion.list) { store.trash(thread.id) }
    }

    private func reply() {
        guard let thread else { return }
        router.draft = .reply(to: thread, from: store.account)
    }

    private func replyAll() {
        guard let thread else { return }
        router.draft = .reply(to: thread, from: store.account, all: true)
    }

    private func forward() {
        guard let thread else { return }
        router.draft = .forward(thread)
    }
}
