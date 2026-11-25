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
        .threadSwipeActions(thread, insets: EdgeInsets(top: Spacing.s, leading: Spacing.m, bottom: Spacing.s, trailing: Spacing.m))
        .listRowBackground((isPinned || isBulkSelected) ? Palette.accentTint : Palette.surface)
        .listRowSeparatorTint(Palette.separator)
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
/// The modifier owns the row's insets: on iOS the row slides across the whole cell.
struct ThreadSwipeActions: ViewModifier {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router: Router?

    let thread: MailThread
    let insets: EdgeInsets

    private var prefs: MailPreferences { .shared }

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .swipeRow(
                id: thread.id,
                insets: insets,
                isEnabled: !store.isSelecting,
                leading: items(prefs.leadingSwipe, prefs.leadingSecondarySwipe),
                trailing: items(prefs.trailingSwipe, prefs.trailingSecondarySwipe)
            )
        #else
        content
            .listRowInsets(insets)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                buttons(items(prefs.trailingSwipe, prefs.trailingSecondarySwipe))
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                buttons(items(prefs.leadingSwipe, prefs.leadingSecondarySwipe))
            }
        #endif
    }

    #if !os(iOS)
    @ViewBuilder
    private func buttons(_ items: [SwipeItem]) -> some View {
        ForEach(items) { item in
            Button(item.title, systemImage: item.symbol, role: item.removesRow ? .destructive : nil, action: item.action)
                .tint(item.tint)
        }
    }
    #endif

    private func items(_ primary: SwipeAction, _ secondary: SwipeAction) -> [SwipeItem] {
        let first = item(for: primary)
        let second = secondary == primary ? nil : item(for: secondary)
        return [first, second].compactMap { $0 }
    }

    private func item(for action: SwipeAction) -> SwipeItem? {
        switch action {
        case .archive:
            if thread.folder == .archive || thread.folder == .trash {
                SwipeItem(title: "Inbox", symbol: "tray.and.arrow.down", tint: Palette.accentFill, removesRow: !store.hasSearchQuery, action: moveToInbox)
            } else {
                SwipeItem(title: "Archive", symbol: "archivebox", tint: Palette.accentFill, removesRow: store.archiveRemovesRow, action: archive)
            }
        case .delete:
            thread.folder == .trash ? nil
                : SwipeItem(title: "Delete", symbol: "trash", tint: Palette.destructiveFill, removesRow: true, action: trash)
        case .unread:
            SwipeItem(
                title: thread.isUnread ? "Read" : "Unread",
                symbol: thread.isUnread ? "envelope.open" : "envelope.badge",
                tint: Palette.accentFill,
                removesRow: false,
                action: toggleUnread
            )
        case .pin:
            SwipeItem(
                title: thread.isPinned ? "Unpin" : "Pin",
                symbol: thread.isPinned ? "pin.slash" : "pin",
                tint: Palette.warmFill,
                removesRow: false,
                action: togglePin
            )
        case .star:
            SwipeItem(
                title: thread.isStarred ? "Unstar" : "Star",
                symbol: thread.isStarred ? "star.slash" : "star",
                tint: Palette.warmFill,
                removesRow: false,
                action: toggleStar
            )
        case .snooze:
            thread.folder == .trash ? nil
                : SwipeItem(title: "Snooze", symbol: "clock", tint: Palette.neutralFill, removesRow: false, action: snooze)
        }
    }

    // The row has already slid off; the animation here, and on the list, closes the gap smoothly.
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
    func threadSwipeActions(_ thread: MailThread, insets: EdgeInsets) -> some View {
        modifier(ThreadSwipeActions(thread: thread, insets: insets))
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
