import SwiftUI

/// The Move button: the mailboxes a thread can go to, then the account's labels.
struct MoveMenu: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread?
    /// Called after the thread is moved.
    var onFiled: () -> Void = {}

    private static let mailboxes: [Mailbox] = [.inbox, .archive, .trash]

    var body: some View {
        Menu("Move", systemImage: "folder") {
            if let thread {
                ForEach(Self.mailboxes.filter { $0 != thread.folder }) { mailbox in
                    Button(mailbox.title, systemImage: mailbox.symbol) {
                        move(thread, to: mailbox)
                    }
                }
                Section {
                    ForEach(store.labels) { label in
                        Button(label.name, systemImage: "tag") {
                            move(thread, to: label)
                        }
                    }
                }
            }
        }
        .disabled(thread == nil || thread?.folder == .drafts)
    }

    private func move(_ thread: MailThread, to mailbox: Mailbox) {
        withAnimation(Motion.list) {
            switch mailbox {
            case .archive: store.archive(thread.id)
            case .trash: store.trash(thread.id)
            default: store.move(thread.id, to: mailbox)
            }
        }
        onFiled()
    }

    private func move(_ thread: MailThread, to label: MailLabel) {
        withAnimation(Motion.list) {
            store.move(thread.id, toLabel: label.id)
        }
        onFiled()
    }
}
