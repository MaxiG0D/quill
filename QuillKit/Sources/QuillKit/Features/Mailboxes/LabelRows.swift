import SwiftUI

/// The account's labels as rows, shared by the sidebar and the mailboxes drawer.
struct LabelRows: View {
    @Environment(MailStore.self) private var store

    var onSelect: () -> Void = {}

    @State private var renamingLabel: MailLabel?
    @State private var deletingLabel: MailLabel?

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
            .contextMenu {
                if (store.badge(for: .label(label.id)) ?? 0) > 0 {
                    Button("Mark All as Read", systemImage: "envelope.open") {
                        withAnimation(Motion.quick) { store.markAllRead(in: .label(label.id)) }
                    }
                }
                Button("Rename…", systemImage: "pencil") {
                    renamingLabel = label
                }
                Button("Delete Label", systemImage: "trash", role: .destructive) {
                    deletingLabel = label
                }
            }
        }
        .sheet(item: $renamingLabel) { label in
            LabelEditorSheet(title: "Rename Label", initialName: label.name, confirmTitle: "Rename") { newName in
                await store.renameLabel(label.id, to: newName)
            }
        }
        .confirmationDialog(
            "Delete label “\(deletingLabel?.name ?? "")”?",
            isPresented: Binding(
                get: { deletingLabel != nil },
                set: { if !$0 { deletingLabel = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Label", role: .destructive) {
                if let label = deletingLabel {
                    deletingLabel = nil
                    Task { await store.deleteLabel(label.id) }
                }
            }
            Button("Cancel", role: .cancel) { deletingLabel = nil }
        } message: {
            Text("Messages with this label won’t be deleted.")
        }
    }

    private func select(_ selection: MailboxSelection) {
        withAnimation(Motion.list) {
            store.show(selection)
        }
        onSelect()
    }
}
