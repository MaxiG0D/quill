import SwiftUI

/// A thread in the compact list, with its swipe actions and context menu.
struct ThreadListRow: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread
    var isPinned = false

    var body: some View {
        NavigationLink(value: thread.id) {
            if isPinned {
                PinnedCard(thread: thread)
            } else {
                MailRow(thread: thread)
            }
        }
        .hidesNavigationLinkIndicator()
        .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.m, bottom: Spacing.s, trailing: Spacing.m))
        .listRowBackground(isPinned ? Palette.accentTint : Palette.surface)
        .listRowSeparatorTint(Palette.separator)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Archive", systemImage: "archivebox", role: archiveRemovesRow ? .destructive : nil, action: archive)
                .tint(Palette.accentFill)
            Button("Delete", systemImage: "trash", role: .destructive, action: trash)
                .tint(Palette.destructiveFill)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(
                thread.isUnread ? "Read" : "Unread",
                systemImage: thread.isUnread ? "envelope.open" : "envelope.badge",
                action: toggleUnread
            )
            .tint(Palette.accentFill)
            Button(
                thread.isPinned ? "Unpin" : "Pin",
                systemImage: thread.isPinned ? "pin.slash" : "pin",
                action: togglePin
            )
            .tint(Palette.warmFill)
        }
        .contextMenu {
            ThreadActions(thread: thread)
        }
    }

    private var archiveRemovesRow: Bool { store.archiveRemovesRow }

    // No withAnimation here: the system animates the row off from the swipe.
    private func archive() {
        store.archive(thread.id)
    }

    private func trash() {
        store.trash(thread.id)
    }

    private func toggleUnread() {
        withAnimation(Motion.quick) { store.toggleUnread(thread.id) }
    }

    private func togglePin() {
        withAnimation(Motion.list) { store.togglePin(thread.id) }
    }
}

extension MailStore {
    /// Whether archiving takes a thread out of the list being shown. A full swipe only slides the
    /// row away when it will leave; a label, Starred or Snoozed keeps the thread in view.
    var archiveRemovesRow: Bool {
        switch selection {
        case .label, .mailbox(.starred), .mailbox(.snoozed): false
        case .mailbox: true
        }
    }
}
