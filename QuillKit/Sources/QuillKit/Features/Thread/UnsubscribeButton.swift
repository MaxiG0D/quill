import SwiftUI

/// Leaves the mailing list a message came from, then offers to clear the sender's mail from the Inbox.
struct UnsubscribeButton: View {
    @Environment(MailStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.closeThread) private var closeThread

    let message: Message
    let threadID: MailThread.ID

    @State private var isWorking = false
    @State private var leftovers: [MailThread.ID] = []
    @State private var isOfferingArchive = false

    var body: some View {
        let isDone = store.isUnsubscribed(from: message.sender)
        Button(action: unsubscribe) {
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
            "Unsubscribed from \(message.sender.displayName)",
            isPresented: $isOfferingArchive,
            titleVisibility: .visible
        ) {
            Button(leftovers.count == 1 ? "Archive Email" : "Archive \(leftovers.count) Emails", action: archive)
            Button("Keep", role: .cancel) {}
        }
    }

    private func unsubscribe() {
        isWorking = true
        Task {
            let isDone = await store.unsubscribe(from: message) { openURL($0) }
            isWorking = false
            guard isDone else { return }
            leftovers = store.inboxThreads(from: message.sender)
            isOfferingArchive = !leftovers.isEmpty
        }
    }

    private func archive() {
        withAnimation(Motion.list) {
            store.archive(leftovers)
        }
        if leftovers.contains(threadID) {
            closeThread()
        }
    }
}

extension EnvironmentValues {
    /// Leaves the open conversation, where leaving is something the layout does.
    @Entry var closeThread: @MainActor @Sendable () -> Void = {}
}
