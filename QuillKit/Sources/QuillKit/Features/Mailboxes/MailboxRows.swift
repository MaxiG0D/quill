import SwiftUI

/// The fixed mailboxes as rows, shared by the sidebar and the mailboxes drawer.
struct MailboxRows: View {
    @Environment(MailStore.self) private var store

    var onSelect: () -> Void = {}

    @State private var isConfirmingEmptyTrash = false

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
            .contextMenu {
                if hasUnread(in: .mailbox(mailbox)) {
                    Button("Mark All as Read", systemImage: "envelope.open") {
                        withAnimation(Motion.quick) { store.markAllRead(in: .mailbox(mailbox)) }
                    }
                }
                if mailbox == .trash, store.threads.contains(where: { $0.folder == .trash }) {
                    Button("Empty Trash", systemImage: "trash.slash", role: .destructive) {
                        isConfirmingEmptyTrash = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Empty Trash?",
            isPresented: $isConfirmingEmptyTrash,
            titleVisibility: .visible
        ) {
            Button("Empty Trash", role: .destructive) {
                withAnimation(Motion.list) { store.emptyTrash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Messages in Trash will be permanently deleted.")
        }
    }

    private func hasUnread(in selection: MailboxSelection) -> Bool {
        let now = store.now
        return store.threads.contains { $0.belongs(to: selection, at: now) && $0.isUnread }
    }

    private func select(_ selection: MailboxSelection) {
        withAnimation(Motion.list) {
            store.show(selection)
        }
        onSelect()
    }
}
