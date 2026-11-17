import SwiftUI

/// The account's labels as rows, shared by the sidebar and the mailboxes drawer.
struct LabelRows: View {
    @Environment(MailStore.self) private var store

    var onSelect: () -> Void = {}

    var body: some View {
        ForEach(store.labels) { label in
            SidebarRow(
                title: label.name,
                icon: .swatch(label.tone),
                count: store.badge(for: .label(label.id)),
                isSelected: store.selection == .label(label.id)
            ) {
                select(.label(label.id))
            }
        }
    }

    private func select(_ selection: MailboxSelection) {
        withAnimation(Motion.list) {
            store.show(selection)
        }
        onSelect()
    }
}
