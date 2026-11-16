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
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        ReplyBar(thread: thread)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            StarButton(thread: thread)
                            Menu("More", systemImage: "ellipsis") {
                                ThreadActions(thread: thread, onFiled: close)
                            }
                            .tint(Palette.accent)
                        }
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
