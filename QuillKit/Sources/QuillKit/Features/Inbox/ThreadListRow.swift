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
            Button("Delete", systemImage: "trash", role: .destructive, action: trash)
                .tint(Palette.destructiveFill)
            Button("Archive", systemImage: "archivebox", action: archive)
                .tint(Palette.accentFill)
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
