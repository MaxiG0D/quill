import SwiftUI

/// The triage actions for one thread, for context menus and the More menu.
struct ThreadActions: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router: Router?

    let thread: MailThread
    /// False where Label and Move already have buttons of their own.
    var hasMenus = true
    /// False where Archive and Delete already have buttons of their own.
    var hasTriage = true
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
        if thread.snoozedUntil != nil {
            Button("Unsnooze", systemImage: "bell.slash", action: unsnooze)
        }
        if thread.folder != .trash {
            Menu("Snooze", systemImage: "clock") {
                ForEach(SnoozeOption.allCases) { option in
                    Button(option.title, systemImage: option.symbol) {
                        snooze(option)
                    }
                }
                if let router {
                    Divider()
                    Button("Pick Date & Time…", systemImage: "calendar.badge.clock") {
                        router.snoozingThreadID = thread.id
                    }
                }
            }
        }
        Button("Print…", systemImage: "printer") {
            ThreadPrinter.shared.printThread(thread, timestamp: store.timestamp)
        }
        if hasMenus || hasTriage { Divider() }
        if hasMenus {
            LabelMenu(thread: thread)
            MoveMenu(thread: thread, onFiled: onFiled)
        }
        if hasTriage, thread.folder == .archive || thread.folder == .trash {
            Button("Move to Inbox", systemImage: Mailbox.inbox.symbol) {
                move(to: .inbox)
            }
        }
        if hasTriage, thread.folder != .archive {
            Button("Archive", systemImage: "archivebox") {
                move(to: .archive)
            }
        }
        if thread.folder != .trash && thread.folder != .drafts {
            Button("Mark as Spam", systemImage: "exclamationmark.octagon", action: markSpam)
        }
        if hasTriage, thread.folder != .trash {
            Button("Delete", systemImage: "trash", role: .destructive) {
                move(to: .trash)
            }
        }
        if thread.folder == .trash {
            Button("Delete Permanently", systemImage: "trash.slash", role: .destructive, action: deletePermanently)
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

    private func unsnooze() {
        withAnimation(Motion.list) { store.unsnooze(thread.id) }
        onFiled()
    }

    private func markSpam() {
        withAnimation(Motion.list) { store.markAsSpam(thread.id) }
        onFiled()
    }

    private func deletePermanently() {
        withAnimation(Motion.list) { store.deletePermanently(thread.id) }
        onFiled()
    }

    private func move(to mailbox: Mailbox) {
        withAnimation(Motion.list) {
            switch mailbox {
            case .trash: store.trash(thread.id)
            case .archive: store.archive(thread.id)
            default: store.move(thread.id, to: mailbox)
            }
        }
        onFiled()
    }
}
