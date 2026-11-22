import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A thread in the wide layout's list column. Selected rows sit on the accent tint.
struct ThreadColumnRow: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread
    var query = ""
    var excerpt: String?
    var onFocus: () -> Void = {}

    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            MailRow(thread: thread, avatarSize: avatarSize, query: query, excerpt: excerpt, isSelected: isSelected)
                .padding(Spacing.s)
                .background(background, in: .rect(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            ThreadActions(thread: thread)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(Motion.quick, value: isSelected)
        .animation(Motion.quick, value: isHovering)
        #if !os(macOS)
        .threadSwipeActions(thread)
        .plainColumnRow()
        #endif
    }

    private var isSelected: Bool {
        store.selectedThreadID == thread.id || store.selectedThreadIDs.contains(thread.id)
    }

    private var background: Color {
        if isSelected { return Palette.accentTint }
        return isHovering ? Palette.fill : .clear
    }

    private var avatarSize: MonogramAvatar.Size {
        #if os(macOS)
        .compact
        #else
        .medium
        #endif
    }

    private func select() {
        onFocus()
        if store.isSelecting {
            withAnimation(Motion.quick) { store.toggleSelection(thread.id) }
            return
        }
        #if os(macOS)
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if store.selectedThreadIDs.isEmpty, let current = store.selectedThreadID {
                store.toggleSelection(current)
            }
            withAnimation(Motion.quick) { store.toggleSelection(thread.id) }
            return
        }
        if flags.contains(.shift) {
            withAnimation(Motion.quick) { store.selectRange(to: thread.id) }
            return
        }
        #endif
        if !store.selectedThreadIDs.isEmpty {
            store.clearSelection()
        }
        if store.hasSearchQuery {
            store.recordSearch(store.searchQuery)
        }
        store.select(thread.id)
    }
}

extension View {
    /// Strips a List row to the bare content the column draws itself.
    func plainColumnRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 1, leading: Spacing.xs, bottom: 1, trailing: Spacing.xs))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
