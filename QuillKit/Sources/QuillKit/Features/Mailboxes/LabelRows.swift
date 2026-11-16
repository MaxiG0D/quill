import SwiftUI

/// The account's labels as rows, shared by the sidebar and the Mailboxes sheet.
struct LabelRows: View {
    @Environment(MailStore.self) private var store

    var isCard = false
    var onSelect: () -> Void = {}

    var body: some View {
        ForEach(store.labels) { label in
            SidebarRow(
                title: label.name,
                icon: .swatch(label.tone),
                count: store.badge(for: .label(label.id)),
                isSelected: store.selection == .label(label.id),
                isCard: isCard
            ) {
                select(.label(label.id))
            }
            if isCard && label != store.labels.last {
                Divider()
                    .overlay(Palette.separator)
                    .padding(.leading, 60)
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
