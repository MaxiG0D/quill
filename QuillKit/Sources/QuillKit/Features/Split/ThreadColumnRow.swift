import SwiftUI

/// A thread in the wide layout's list column. Selected rows sit on the accent tint.
struct ThreadColumnRow: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread
    var query = ""
    var excerpt: String?

    var body: some View {
        Button(action: select) {
            MailRow(thread: thread, avatarSize: avatarSize, query: query, excerpt: excerpt)
                .padding(Spacing.s)
                .background(background, in: .rect(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
        .contextMenu {
            ThreadActions(thread: thread)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(Motion.quick, value: isSelected)
        #if !os(macOS)
        .threadSwipeActions(thread)
        .plainColumnRow()
        #endif
    }

    private var isSelected: Bool {
        store.selectedThreadID == thread.id
    }

    private var background: Color {
        isSelected ? Palette.accentTint : .clear
    }

    private var avatarSize: MonogramAvatar.Size {
        #if os(macOS)
        .compact
        #else
        .medium
        #endif
    }

    private func select() {
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
