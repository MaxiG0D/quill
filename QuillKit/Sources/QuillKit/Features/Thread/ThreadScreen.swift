import SwiftUI

/// A pushed conversation in the compact layout.
struct ThreadScreen: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    let threadID: MailThread.ID

    private var thread: MailThread? {
        store.thread(threadID)
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if let thread {
                ThreadConversation(thread: thread)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button("Archive", systemImage: "archivebox") {
                                file(thread.id, trash: false)
                            }
                            .tint(Palette.accent)
                            .keyboardShortcut("e", modifiers: .command)
                            .disabled(thread.folder == .archive)
                            MoveMenu(thread: thread, onFiled: close)
                                .tint(Palette.accent)
                            Button("Delete", systemImage: "trash") {
                                file(thread.id, trash: true)
                            }
                            .tint(Palette.destructive)
                            .keyboardShortcut(.delete, modifiers: .command)
                            .disabled(thread.folder == .trash)
                            Menu("More", systemImage: "ellipsis") {
                                ThreadActions(thread: thread, hasMenus: false, hasTriage: false, onFiled: close)
                                LabelMenu(thread: thread)
                            }
                            .tint(Palette.accent)
                        }
                        // The system places these: along the bottom, or in the side strip on a device that has one.
                        #if os(iOS)
                        ToolbarItemGroup(placement: .bottomBar) {
                            if thread.folder == .drafts {
                                Button("Edit Draft", systemImage: "pencil") {
                                    router.draft = .editing(thread)
                                }
                                .labelStyle(.titleAndIcon)
                                .fontWeight(.semibold)
                                .buttonStyle(.borderedProminent)
                                .tint(Palette.accentFill)
                            } else {
                                ReplyActions(thread: thread)
                                    .tint(Palette.accent)
                            }
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
        .onChange(of: thread == nil) { _, missing in
            if missing { dismiss() }
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
