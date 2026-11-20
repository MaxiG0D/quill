import SwiftUI

/// A pushed conversation in the compact layout.
struct ThreadScreen: View {
    @Environment(MailStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let threadID: MailThread.ID

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if let thread = store.thread(threadID) {
                ThreadConversation(thread: thread)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button("Archive", systemImage: "archivebox") {
                                file(thread.id, trash: false)
                            }
                            .tint(Palette.accent)
                            MoveMenu(thread: thread, onFiled: close)
                                .tint(Palette.accent)
                            Button("Delete", systemImage: "trash") {
                                file(thread.id, trash: true)
                            }
                            .tint(Palette.destructive)
                            Menu("More", systemImage: "ellipsis") {
                                ThreadActions(thread: thread, hasMenus: false, hasTriage: false, onFiled: close)
                                LabelMenu(thread: thread)
                            }
                            .tint(Palette.accent)
                        }
                        // The system places these: along the bottom, or in the side strip on a device that has one.
                        #if os(iOS)
                        ToolbarItemGroup(placement: .bottomBar) {
                            ReplyActions(thread: thread)
                                .tint(Palette.accent)
                        }
                        #endif
                    }
            }
        }
        .environment(\.closeThread, { dismiss() })
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .task(id: threadID) {
            store.markRead(threadID)
        }
    }

    private func file(_ id: MailThread.ID, trash: Bool) {
        withAnimation(Motion.list) {
            if trash { store.trash(id) } else { store.archive(id) }
        }
        close()
    }

    private func close() {
        dismiss()
    }
}
