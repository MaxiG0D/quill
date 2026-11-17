import SwiftUI

/// One thread in a list: who it is from, what it is about, and its state.
struct MailRow: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread
    var avatarSize: MonogramAvatar.Size = .medium
    /// A search query to mark in the subject and preview.
    var query = ""
    /// Replaces the preview line, for search excerpts.
    var excerpt: String?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            if let sender = thread.sender {
                MonogramAvatar(sender, size: avatarSize)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs + 2) {
                    if thread.isUnread {
                        UnreadMark()
                    }
                    Text(thread.sender?.displayName ?? "")
                        .textRole(.sender(unread: thread.isUnread))
                        .foregroundStyle(Palette.label)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.xs)
                    ThreadStatus(thread: thread)
                }
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    HighlightedText(text: thread.subject, query: query)
                        .textRole(.subject(unread: thread.isUnread))
                        .foregroundStyle(thread.isUnread ? Palette.label : Palette.secondaryLabel)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.xs)
                    if thread.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryLabel)
                            .accessibilityLabel("Has attachment")
                    }
                    if let label = store.labels(for: thread).first {
                        LabelChip(label)
                    }
                }
                HighlightedText(text: excerpt ?? thread.preview, query: query)
                    .textRole(.preview)
                    .foregroundStyle(thread.isUnread ? Palette.secondaryLabel : Palette.tertiaryLabel)
                    .lineLimit(1)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] + Spacing.m }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(thread.isUnread ? "Unread" : "")
    }
}

#Preview {
    let store = MailStore(snapshot: SampleData.snapshot(now: .now))
    List(store.visibleThreads) { thread in
        MailRow(thread: thread)
    }
    .environment(store)
}
