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
        .threadSwipeActions(thread)
        .contextMenu {
            ThreadActions(thread: thread)
        }
    }
}

/// The swipe actions every thread list shares. Archive comes first, so a full swipe archives; it is
/// destructive, which makes the row slide off with the finger, only where it leaves the list.
struct ThreadSwipeActions: ViewModifier {
    @Environment(MailStore.self) private var store

    let thread: MailThread

    func body(content: Content) -> some View {
        content
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Archive", systemImage: "archivebox", role: store.archiveRemovesRow ? .destructive : nil, action: archive)
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
    }

    // The system slides the row off; the animation here, and on the list, closes the gap smoothly.
    private func archive() {
        withAnimation(Motion.list) { store.archive(thread.id) }
    }

    private func trash() {
        withAnimation(Motion.list) { store.trash(thread.id) }
    }

    private func toggleUnread() {
        withAnimation(Motion.quick) { store.toggleUnread(thread.id) }
    }

    private func togglePin() {
        withAnimation(Motion.list) { store.togglePin(thread.id) }
    }
}

extension View {
    func threadSwipeActions(_ thread: MailThread) -> some View {
        modifier(ThreadSwipeActions(thread: thread))
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
