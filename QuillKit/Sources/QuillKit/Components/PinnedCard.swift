import SwiftUI

/// The roomier presentation for a pinned thread: a large monogram, a two-line
/// preview, and the thread's attachment and label.
struct PinnedCard: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top, spacing: Spacing.s) {
                if let sender = thread.sender {
                    MonogramAvatar(sender, size: .large)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs + 2) {
                        if thread.isUnread {
                            UnreadMark()
                        }
                        Text(thread.sender?.displayName ?? "")
                            .textRole(.sender(unread: thread.isUnread))
                            .foregroundStyle(Palette.label)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Spacing.xs)
                        ThreadStatus(thread: thread)
                            .fixedSize()
                    }
                    Text(thread.subject)
                        .textRole(.sender(unread: false))
                        .fontWeight(thread.isUnread ? .semibold : .regular)
                        .foregroundStyle(thread.isUnread ? Palette.label : Palette.secondaryLabel)
                        .lineLimit(1)
                }
            }
            Text(thread.preview)
                .font(.subheadline)
                .foregroundStyle(thread.isUnread ? Palette.secondaryLabel : Palette.tertiaryLabel)
                .lineLimit(2)
            if !accessories.isEmpty {
                HStack(spacing: Spacing.xs) {
                    if let attachment = thread.attachments.last {
                        AttachmentChip(attachment: attachment)
                    }
                    ForEach(store.labels(for: thread)) { label in
                        LabelChip(label)
                    }
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(thread.isUnread ? "Unread" : "")
    }

    private var accessories: [String] {
        thread.attachments.map(\.id) + thread.labelIDs
    }
}
