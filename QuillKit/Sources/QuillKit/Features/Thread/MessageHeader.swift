import SwiftUI

/// Who a message is from and when. Collapsed, it also carries a one-line preview;
/// expanded, it offers full recipient details and per-message reply/forward actions.
struct MessageHeader: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router: Router?

    let message: Message
    var thread: MailThread? = nil
    let isExpanded: Bool
    /// Shows the full date and the thread's star, as the wide layout does.
    var isDetailed = false
    var isStarred = false
    /// When set, tapping the header collapses or expands the message without nesting buttons.
    var onToggle: (() -> Void)? = nil

    @State private var showsDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .center, spacing: Spacing.s) {
                if let onToggle, !isExpanded {
                    Button(action: onToggle) {
                        collapsedContent
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Expands the message")
                } else if let onToggle {
                    expandedContent(onToggle: onToggle)
                } else {
                    staticContent
                        .accessibilityElement(children: .combine)
                        .accessibilityHint(isExpanded ? "Collapses the message" : "Expands the message")
                }

                if isExpanded, let thread, let router {
                    perMessageMenu(thread: thread, router: router)
                }

                if isExpanded, let thread, message.unsubscribe != nil {
                    UnsubscribeButton(message: message, threadID: thread.id)
                }
            }

            if isExpanded && showsDetails {
                MessageRecipientDetails(
                    message: message,
                    dateText: store.timestamp.long(message.date)
                )
                .transition(.opacity)
            }
        }
    }

    private var collapsedContent: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            MonogramAvatar(message.sender, size: .compact)
            VStack(alignment: .leading, spacing: 2) {
                senderRow
                Text(message.preview)
                    .textRole(.preview)
                    .foregroundStyle(Palette.secondaryLabel)
                    .lineLimit(1)
            }
        }
        .contentShape(.rect)
    }

    private func expandedContent(onToggle: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Button(action: onToggle) {
                MonogramAvatar(message.sender, size: .medium)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Collapse message")

            VStack(alignment: .leading, spacing: 2) {
                Button(action: onToggle) {
                    senderRow
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Collapses the message")

                if let recipientsSummary {
                    Button {
                        withAnimation(Motion.expand) { showsDetails.toggle() }
                    } label: {
                        HStack(spacing: 3) {
                            Text(recipientsSummary)
                                .textRole(.meta)
                                .foregroundStyle(Palette.secondaryLabel)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Image(systemName: showsDetails ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Palette.tertiaryLabel)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsDetails ? "Hide recipient details" : "Show recipient details")
                }
            }
        }
    }

    private var staticContent: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            MonogramAvatar(message.sender, size: isExpanded ? .medium : .compact)
            VStack(alignment: .leading, spacing: 2) {
                senderRow
                if isExpanded {
                    if let recipientsSummary {
                        Text(recipientsSummary)
                            .textRole(.meta)
                            .foregroundStyle(Palette.secondaryLabel)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    Text(message.preview)
                        .textRole(.preview)
                        .foregroundStyle(Palette.secondaryLabel)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(.rect)
    }

    private var senderRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(message.sender.displayName)
                .textRole(.sender(unread: isExpanded))
                .fontWeight(isExpanded ? .bold : .semibold)
                .foregroundStyle(Palette.label)
                .lineLimit(isExpanded ? 3 : 1)
                .fixedSize(horizontal: false, vertical: isExpanded)
                .allowsTightening(true)
                .minimumScaleFactor(isExpanded ? 1 : 0.85)
                .layoutPriority(1)
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
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func perMessageMenu(thread: MailThread, router: Router) -> some View {
        Menu {
            Button("Reply", systemImage: "arrowshape.turn.up.left") {
                router.draft = Draft.reply(to: message, in: thread, from: store.account, all: false)
            }
            if hasMultipleRecipients {
                Button("Reply All", systemImage: "arrowshape.turn.up.left.2") {
                    router.draft = Draft.reply(to: message, in: thread, from: store.account, all: true)
                }
            }
            Button("Forward", systemImage: "arrowshape.turn.up.right") {
                router.draft = Draft.forward(message, in: thread)
            }
            Divider()
            Button(showsDetails ? "Hide Details" : "Show Details", systemImage: "info.circle") {
                withAnimation(Motion.expand) { showsDetails.toggle() }
            }
        } label: {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.secondaryLabel)
                .frame(width: 28, height: 28)
                .background(Palette.fill, in: .circle)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help("Reply or Forward this message")
        .accessibilityLabel("Message actions")
    }

    private var hasMultipleRecipients: Bool {
        let me = store.account.email.lowercased()
        let others = Set(([message.sender] + message.to + message.cc).map { $0.email.lowercased() }.filter { !$0.isEmpty && $0 != me })
        return others.count > 1
    }

    private var recipientsSummary: String? {
        let me = store.account.email.lowercased()
        func label(_ contact: Contact) -> String {
            contact.email.lowercased() == me ? "me" : contact.shortName
        }
        var parts: [String] = []
        if !message.to.isEmpty {
            parts.append("to \(message.to.map(label).joined(separator: ", "))")
        }
        if !message.cc.isEmpty {
            parts.append("cc \(message.cc.map(label).joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var date: String {
        isDetailed && isExpanded ? store.timestamp.long(message.date) : store.timestamp.short(message.date)
    }
}
