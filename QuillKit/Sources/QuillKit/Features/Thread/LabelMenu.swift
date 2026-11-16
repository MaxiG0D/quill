import SwiftUI

/// The Label button: the account's labels, checked when they are on the thread.
/// The menu stays open so several can be changed in one visit.
struct LabelMenu: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread?

    var body: some View {
        Menu("Label", systemImage: "tag") {
            if let thread {
                ForEach(store.labels) { label in
                    Toggle(label.name, isOn: isOn(label, for: thread))
                }
            }
        }
        .menuActionDismissBehavior(.disabled)
        .disabled(thread == nil || store.labels.isEmpty)
    }

    private func isOn(_ label: MailLabel, for thread: MailThread) -> Binding<Bool> {
        Binding {
            thread.labelIDs.contains(label.id)
        } set: { isOn in
            withAnimation(Motion.quick) {
                store.setLabel(label.id, on: thread.id, isOn: isOn)
            }
        }
    }
}
