import SwiftUI

/// A thread in the compact list, with its swipe actions and context menu.
struct ThreadListRow: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread
    var isPinned = false

    private var isBulkSelected: Bool {
        store.selectedThreadIDs.contains(thread.id)
    }

    var body: some View {
        Group {
            if store.isSelecting {
                Button {
                    withAnimation(Motion.quick) { store.toggleSelection(thread.id) }
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: thread.id) {
                    rowContent
                }
                .hidesNavigationLinkIndicator()
            }
        }
        .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.m, bottom: Spacing.s, trailing: Spacing.m))
        .listRowBackground((isPinned || isBulkSelected) ? Palette.accentTint : Palette.surface)
        .listRowSeparatorTint(Palette.separator)
        .threadSwipeActions(thread)
        .contextMenu {
            ThreadActions(thread: thread)
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        if isPinned {
            PinnedCard(thread: thread)
        } else {
            MailRow(thread: thread, isSelected: isBulkSelected)
        }
    }
}

/// The swipe actions every thread list shares, driven by user swipe preferences in Settings.
struct ThreadSwipeActions: ViewModifier {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router: Router?

    let thread: MailThread

    private var prefs: MailPreferences { .shared }

    func body(content: Content) -> some View {
        content
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            swipeButton(for: prefs.trailingSwipe)
            if prefs.trailingSecondarySwipe != prefs.trailingSwipe {
                swipeButton(for: prefs.trailingSecondarySwipe)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            swipeButton(for: prefs.leadingSwipe)
            if prefs.leadingSecondarySwipe != prefs.leadingSwipe {
                swipeButton(for: prefs.leadingSecondarySwipe)
            }
        }
    }

    @ViewBuilder
    private func swipeButton(for action: SwipeAction) -> some View {
        switch action {
        case .archive:
            if thread.folder == .archive || thread.folder == .trash {
                Button("Inbox", systemImage: "tray.and.arrow.down", role: store.hasSearchQuery ? nil : .destructive, action: moveToInbox)
                    .tint(Palette.accentFill)
            } else {
                Button("Archive", systemImage: "archivebox", role: store.archiveRemovesRow ? .destructive : nil, action: archive)
                    .tint(Palette.accentFill)
            }
        case .delete:
            if thread.folder != .trash {
                Button("Delete", systemImage: "trash", role: .destructive, action: trash)
                    .tint(Palette.destructiveFill)
            }
        case .unread:
            Button(
                thread.isUnread ? "Read" : "Unread",
                systemImage: thread.isUnread ? "envelope.open" : "envelope.badge",
                action: toggleUnread
            )
            .tint(Palette.accentFill)
        case .pin:
            Button(
                thread.isPinned ? "Unpin" : "Pin",
                systemImage: thread.isPinned ? "pin.slash" : "pin",
                action: togglePin
            )
            .tint(Palette.warmFill)
        case .star:
            Button(
                thread.isStarred ? "Unstar" : "Star",
                systemImage: thread.isStarred ? "star.slash" : "star",
                action: toggleStar
            )
            .tint(Palette.warmFill)
        case .snooze:
            if thread.folder != .trash {
                Button("Snooze", systemImage: "clock", action: snooze)
                    .tint(Palette.neutralFill)
            }
        }
    }

    // The system slides the row off; the animation here, and on the list, closes the gap smoothly.
    private func archive() {
        withAnimation(Motion.list) { store.archive(thread.id) }
    }

    private func moveToInbox() {
        withAnimation(Motion.list) { store.move(thread.id, to: .inbox) }
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

    private func toggleStar() {
        withAnimation(Motion.quick) { store.toggleStar(thread.id) }
    }

    private func snooze() {
        if let router {
            router.snoozingThreadID = thread.id
        } else {
            withAnimation(Motion.list) { store.snooze(thread.id, until: .tomorrow) }
        }
    }
}

extension View {
    func threadSwipeActions(_ thread: MailThread) -> some View {
        modifier(ThreadSwipeActions(thread: thread))
    }
}

extension MailStore {
    /// Whether archiving takes a thread out of the list being shown. A full swipe only slides the
    /// row away when it will leave; a label, Starred, Snoozed, Archive or Search keeps the thread in view.
    var archiveRemovesRow: Bool {
        if hasSearchQuery { return false }
        return switch selection {
        case .label, .mailbox(.starred), .mailbox(.snoozed), .mailbox(.archive): false
        case .mailbox: true
        }
    }
}
