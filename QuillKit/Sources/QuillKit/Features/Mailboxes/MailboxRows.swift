import SwiftUI

/// The fixed mailboxes as rows, shared by the sidebar and the Mailboxes sheet.
struct MailboxRows: View {
    @Environment(MailStore.self) private var store

    var isCard = false
    var onSelect: () -> Void = {}

    var body: some View {
        ForEach(Mailbox.allCases) { mailbox in
            SidebarRow(
                title: mailbox.title,
                icon: .symbol(mailbox.symbol),
                count: store.badge(for: .mailbox(mailbox)),
                isSelected: store.selection == .mailbox(mailbox),
                isCard: isCard
            ) {
                select(.mailbox(mailbox))
            }
            if isCard && mailbox != Mailbox.allCases.last {
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
