import SwiftUI

/// The triage actions for one thread, for context menus and the More menu.
struct ThreadActions: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread
    /// False where Label and Move already have buttons of their own.
    var hasMenus = true
    /// Called after an action removes the thread from the current list.
    var onFiled: () -> Void = {}

    var body: some View {
        Button(
            thread.isStarred ? "Remove Star" : "Star",
            systemImage: thread.isStarred ? "star.slash" : "star",
            action: toggleStar
        )
        Button(
            thread.isPinned ? "Unpin" : "Pin",
            systemImage: thread.isPinned ? "pin.slash" : "pin",
            action: togglePin
        )
        Button(
            thread.isUnread ? "Mark as Read" : "Mark as Unread",
            systemImage: thread.isUnread ? "envelope.open" : "envelope.badge",
            action: toggleUnread
        )
        Menu("Snooze", systemImage: "clock") {
            ForEach(SnoozeOption.allCases) { option in
                Button(option.title, systemImage: option.symbol) {
                    snooze(option)
                }
            }
        }
        Divider()
        if hasMenus {
            LabelMenu(thread: thread)
            MoveMenu(thread: thread, onFiled: onFiled)
        }
        if thread.folder != .archive {
            Button("Archive", systemImage: "archivebox") {
                move(to: .archive)
            }
        }
        if thread.folder != .trash {
            Button("Delete", systemImage: "trash", role: .destructive) {
                move(to: .trash)
            }
        }
    }

    private func toggleStar() {
        withAnimation(Motion.quick) { store.toggleStar(thread.id) }
    }

    private func togglePin() {
        withAnimation(Motion.list) { store.togglePin(thread.id) }
    }

    private func toggleUnread() {
        withAnimation(Motion.quick) { store.toggleUnread(thread.id) }
    }

    private func snooze(_ option: SnoozeOption) {
        withAnimation(Motion.list) { store.snooze(thread.id, until: option) }
        onFiled()
    }

    private func move(to mailbox: Mailbox) {
        withAnimation(Motion.list) {
            if mailbox == .trash {
                store.trash(thread.id)
            } else {
                store.archive(thread.id)
            }
        }
        onFiled()
    }
}
