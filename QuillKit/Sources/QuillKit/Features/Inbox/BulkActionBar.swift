import SwiftUI

/// Floating bar shown when multiple threads are selected for bulk triage.
struct BulkActionBar: View {
    @Environment(MailStore.self) private var store

    var body: some View {
        let ids = Array(store.selectedThreadIDs)
        let hasUnread = ids.contains { store.thread($0)?.isUnread == true }
        let hasUnstarred = ids.contains { store.thread($0)?.isStarred == false }

        HStack(spacing: Spacing.s) {
            Text("\(ids.count) selected")
                .textRole(.meta)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.label)
                .padding(.leading, Spacing.xs)
            Spacer(minLength: Spacing.xs)
            IconButton(
                hasUnread ? "Mark Read" : "Mark Unread",
                systemImage: hasUnread ? "envelope.open" : "envelope.badge",
                width: 36,
                height: 36
            ) {
                withAnimation(Motion.quick) { store.markUnread(ids, isUnread: !hasUnread) }
            }
            .foregroundStyle(Palette.accent)
            .disabled(ids.isEmpty)

            IconButton(
                hasUnstarred ? "Star" : "Remove Star",
                systemImage: hasUnstarred ? "star" : "star.slash",
                width: 36,
                height: 36
            ) {
                withAnimation(Motion.quick) { store.setStarred(ids, isStarred: hasUnstarred) }
            }
            .foregroundStyle(Palette.warm)
            .disabled(ids.isEmpty)

            IconButton("Archive", systemImage: "archivebox", width: 36, height: 36) {
                withAnimation(Motion.list) {
                    store.archive(ids)
                    store.clearSelection()
                }
            }
            .foregroundStyle(Palette.accent)
            .disabled(ids.isEmpty)

            IconButton("Delete", systemImage: "trash", width: 36, height: 36) {
                withAnimation(Motion.list) { store.trash(ids) }
            }
            .foregroundStyle(Palette.destructive)
            .disabled(ids.isEmpty)

            Button("Done") {
                withAnimation(Motion.quick) { store.clearSelection() }
            }
            .textRole(.meta)
            .fontWeight(.semibold)
            .foregroundStyle(Palette.secondaryLabel)
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.xs)
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(Palette.surface, in: .capsule)
        .overlay {
            Capsule().strokeBorder(Palette.separator, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}
