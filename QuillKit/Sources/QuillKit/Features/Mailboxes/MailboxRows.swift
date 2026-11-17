import SwiftUI

/// The fixed mailboxes as rows, shared by the sidebar and the mailboxes drawer.
struct MailboxRows: View {
    @Environment(MailStore.self) private var store

    var onSelect: () -> Void = {}

    var body: some View {
        ForEach(Mailbox.allCases) { mailbox in
            SidebarRow(
                title: mailbox.title,
                icon: .symbol(mailbox.symbol),
                count: store.badge(for: .mailbox(mailbox)),
                isSelected: store.selection == .mailbox(mailbox)
            ) {
                select(.mailbox(mailbox))
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
