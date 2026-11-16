import SwiftUI

/// The large serif title with the unread count set beside it in italics.
struct MailboxTitle: View {
    let title: String
    var count = 0

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
