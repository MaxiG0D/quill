import SwiftUI

/// Who a message is from and when. Collapsed, it also carries a one-line preview.
struct MessageHeader: View {
    @Environment(MailStore.self) private var store

    let message: Message
    let isExpanded: Bool
    /// Shows the full date and the thread's star, as the wide layout does.
    var isDetailed = false
    var isStarred = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            MonogramAvatar(message.sender, size: isExpanded ? .medium : .compact)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(message.sender.displayName)
                        .textRole(.sender(unread: isExpanded))
                        .fontWeight(isExpanded ? .bold : .semibold)
                        .foregroundStyle(Palette.label)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.xs)
                    if isDetailed && isStarred && isExpanded {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Palette.warm)
                            .accessibilityLabel("Starred")
                    }
                    Text(date)
                        .textRole(.meta)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                if !isExpanded {
                    Text(message.preview)
                        .textRole(.preview)
                        .foregroundStyle(Palette.secondaryLabel)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Collapses the message" : "Expands the message")
    }

    private var date: String {
        isDetailed && isExpanded ? store.timestamp.long(message.date) : store.timestamp.short(message.date)
    }
}
