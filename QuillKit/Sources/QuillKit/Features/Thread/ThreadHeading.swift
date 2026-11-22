import SwiftUI

/// A thread's subject with its label and mailbox chips.
struct ThreadHeading: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(thread.subject)
                .textRole(.title)
                .foregroundStyle(Palette.label)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("thread-heading")
            FlowLayout(spacing: Spacing.xs) {
                ForEach(store.labels(for: thread)) { label in
                    LabelChip(label)
                }
                LabelChip(name: thread.folder.title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
