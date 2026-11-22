import SwiftUI

/// The roomier presentation for a pinned thread: a large monogram, a two-line
/// preview, and the thread's attachment and label.
struct PinnedCard: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router: Router?

    let thread: MailThread

    @State private var loadingAttachmentID: Attachment.ID?

    private var upcomingEvent: MailEvent? {
        guard let latest = thread.latest,
              let event = MailEventCache.event(in: latest, subject: thread.subject),
              event.isUpcoming(at: store.now) else { return nil }
        return event
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
        let hasAccessories = !thread.attachments.isEmpty || !resolvedLabels.isEmpty || upcomingEvent != nil || signInCode != nil
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top, spacing: Spacing.s) {
                if isInBulkSelection {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isChecked ? Palette.accent : Palette.secondaryLabel)
                        .padding(.top, Spacing.xs)
                }
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
                    Text(thread.subject)
                        .textRole(.subject(unread: thread.isUnread))
                        .foregroundStyle(thread.isUnread ? Palette.label : Palette.secondaryLabel)
                        .lineLimit(1)
                }
            }
            Text(thread.preview)
                .font(.subheadline)
                .foregroundStyle(thread.isUnread ? Palette.secondaryLabel : Palette.tertiaryLabel)
                .lineLimit(2)
            if hasAccessories {
                FlowLayout(spacing: Spacing.xs) {
                    if let code = signInCode {
                        InboxCodeChip(code: code, onTint: true)
                    }
                    if let event = upcomingEvent {
                        EventChip(event: event, now: store.now, onTint: true)
                    }
                    if let attachment = thread.attachments.last {
                        AttachmentChip(
                            attachment: attachment,
                            extraCount: max(thread.attachments.count - 1, 0),
                            onTint: true,
                            isLoading: loadingAttachmentID == attachment.id,
                            onTap: attachment.isAvailable ? { preview(attachment) } : nil
                        )
                    }
                    ForEach(resolvedLabels) { label in
                        LabelChip(label)
                    }
                }
            }
        }
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
