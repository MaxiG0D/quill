import SwiftUI

/// One thread in a list: who it is from, what it is about, and its state.
struct MailRow: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router: Router?

    let thread: MailThread
    var avatarSize: MonogramAvatar.Size = .medium
    /// A search query to mark in the subject and preview.
    var query = ""
    /// Replaces the preview line, for search excerpts.
    var excerpt: String?
    /// True when the row sits on `Palette.accentTint` (selected in the wide layout).
    var isSelected = false

    @State private var loadingAttachmentID: Attachment.ID?

    private var upcomingEvent: MailEvent? {
        guard let latest = thread.latest,
              let event = MailEventCache.event(in: latest, subject: thread.subject),
              event.isUpcoming(at: store.now) else { return nil }
        return event
    }

    /// Where an upcoming event is, so the row can offer directions.
    private var eventAddress: MailAddress? {
        guard upcomingEvent != nil, let latest = thread.latest else { return nil }
        return MailAddressCache.address(in: latest)
    }

    private var signInCode: SignInCode? {
        guard thread.isUnread, let latest = thread.latest else { return nil }
        let body = latest.body.isEmpty ? (latest.snippet ?? "") : latest.body
        return SignInCode.find(in: "\(thread.subject)\n\(body)")
    }

    private var isInBulkSelection: Bool {
        store.isSelecting || !store.selectedThreadIDs.isEmpty
    }

    private var isChecked: Bool {
        store.selectedThreadIDs.contains(thread.id)
    }

    var body: some View {
        let resolvedLabels = store.labels(for: thread)
        let attachments = thread.attachments
        HStack(alignment: .center, spacing: Spacing.s) {
            if isInBulkSelection {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? Palette.accent : Palette.secondaryLabel)
                    .accessibilityLabel(isChecked ? "Selected" : "Not selected")
            }
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
                        .fontWeight(thread.isUnread ? .heavy : .bold)
                        .foregroundStyle(Palette.label)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)
                    if thread.messages.count > 1 {
                        Text("\(thread.messages.count)")
                            .textRole(.meta)
                            .foregroundStyle(Palette.secondaryLabel)
                            .fixedSize()
                            .accessibilityLabel("\(thread.messages.count) messages")
                    }
                    Spacer(minLength: Spacing.xs)
                    ThreadStatus(thread: thread)
                        .fixedSize()
                }
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    HighlightedText(text: thread.subject, query: query, onTint: isSelected)
                        .textRole(.subject(unread: thread.isUnread))
                        .foregroundStyle(thread.isUnread ? Palette.label : Palette.secondaryLabel)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.xs)
                    if let label = resolvedLabels.first {
                        LabelChip(label)
                            .fixedSize()
                        if resolvedLabels.count > 1 {
                            Text("+\(resolvedLabels.count - 1)")
                                .textRole(.meta)
                                .foregroundStyle(Palette.secondaryLabel)
                                .fixedSize()
                        }
                    }
                }
                HighlightedText(text: excerpt ?? thread.preview, query: query, onTint: isSelected)
                    .textRole(.preview)
                    .foregroundStyle(thread.isUnread ? Palette.secondaryLabel : Palette.tertiaryLabel)
                    .lineLimit(1)
                if upcomingEvent != nil || signInCode != nil || !attachments.isEmpty {
                    FlowLayout(spacing: Spacing.xxs + 2) {
                        if let code = signInCode {
                            InboxCodeChip(code: code, onTint: isSelected)
                        }
                        if let event = upcomingEvent {
                            EventChip(event: event, now: store.now, onTint: isSelected)
                        }
                        if let address = eventAddress {
                            DirectionsChip(address: address, onTint: isSelected)
                        }
                        ForEach(Array(attachments.prefix(2).enumerated()), id: \.element.id) { index, attachment in
                            let overflow = index == 1 ? max(attachments.count - 2, 0) : 0
                            AttachmentChip(
                                attachment: attachment,
                                extraCount: overflow,
                                isCompact: true,
                                onTint: isSelected,
                                isLoading: loadingAttachmentID == attachment.id,
                                onTap: attachment.isAvailable ? { preview(attachment) } : nil
                            )
                        }
                    }
                    .padding(.top, Spacing.xxs)
                }
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] + Spacing.m }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(thread.isUnread ? "Unread" : "")
    }

    private func preview(_ attachment: Attachment) {
        guard let router else { return }
        loadingAttachmentID = attachment.id
        Task {
            defer { if loadingAttachmentID == attachment.id { loadingAttachmentID = nil } }
            do {
                router.previewAttachmentURL = try await store.previewFileURL(for: attachment)
            } catch {
                store.alert = error.localizedDescription
            }
        }
    }
}

#Preview {
    let store = MailStore(snapshot: SampleData.snapshot(now: .now))
    List(store.visibleThreads) { thread in
        MailRow(thread: thread)
    }
    .environment(store)
}
