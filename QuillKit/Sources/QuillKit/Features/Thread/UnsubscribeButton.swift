import SwiftUI

/// Leaves the mailing list a message came from and clears the sender's mail from the Inbox, once confirmed.
struct UnsubscribeButton: View {
    @Environment(MailStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.closeThread) private var closeThread

    let message: Message
    let threadID: MailThread.ID

    @State private var isWorking = false
    @State private var isConfirming = false

    var body: some View {
        let isDone = store.isUnsubscribed(from: message.sender)
        Button {
            isConfirming = true
        } label: {
            Text(isDone ? "Unsubscribed" : "Unsubscribe")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isDone ? Palette.secondaryLabel : Palette.accent)
                .lineLimit(1)
                .fixedSize()
                .opacity(isWorking ? 0 : 1)
                .overlay {
                    if isWorking {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(minHeight: Metrics.target)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isDone || isWorking)
        .animation(Motion.quick, value: isDone)
        .confirmationDialog(
            "Unsubscribe from \(message.sender.displayName)?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Unsubscribe", action: unsubscribe)
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Tells the list to unsubscribe first, then clears the sender's Inbox mail on success.
    private func unsubscribe() {
        let leaving = store.inboxThreads(from: message.sender)
        isWorking = true
        Task {
            let done = await store.unsubscribe(from: message) { openURL($0) }
            isWorking = false
            guard done else { return }
            withAnimation(Motion.list) {
                store.archive(leaving)
            }
            if leaving.contains(threadID) {
                closeThread()
            }
        }
    }
}

extension EnvironmentValues {
    /// Leaves the open conversation, where leaving is something the layout does.
    @Entry var closeThread: @MainActor @Sendable () -> Void = {}
}
