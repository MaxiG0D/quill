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
                            StarButton(thread: thread)
                            LabelMenu(thread: thread)
                                .tint(Palette.accent)
                            MoveMenu(thread: thread, onFiled: close)
                                .tint(Palette.accent)
                            Menu("More", systemImage: "ellipsis") {
                                ThreadActions(thread: thread, hasMenus: false, onFiled: close)
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
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .task(id: threadID) {
            store.markRead(threadID)
        }
    }

    private func close() {
        dismiss()
    }
}
