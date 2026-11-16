import SwiftUI

/// The large serif title with the unread count set beside it in italics.
struct MailboxTitle: View {
    let title: String
    var count = 0
    /// Adds the chevron that marks the title as the way to the other mailboxes.
    var opensMailboxes = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(title)
                .textRole(.display)
                .foregroundStyle(Palette.label)
            if count > 0 {
                Text(count, format: .number)
                    .textRole(.count)
                    .foregroundStyle(Palette.accent)
                    .contentTransition(.numericText())
                    .transition(.opacity)
                    .accessibilityLabel("\(count) unread")
            }
            if opensMailboxes {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundStyle(Palette.secondaryLabel)
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .animation(Motion.quick, value: count)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    MailboxTitle(title: "Inbox", count: 2)
        .padding()
}
