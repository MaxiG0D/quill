import Foundation

/// Turns Gmail's threads and labels into Quill's models.
struct GmailMapper: Sendable {
    let account: Contact
    /// The account's own labels. Gmail's system labels become mailboxes and flags instead.
    let labels: [MailLabel]

    /// The labels a person made themselves, in name order.
    static func labels(from resources: [GmailResource.Label]) -> [MailLabel] {
        resources
            .filter { $0.type == "user" }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { MailLabel(id: $0.id, name: $0.name, tone: .stable(for: $0.name)) }
    }

    func thread(from resource: GmailResource.Thread) -> MappedThread? {
        let all = (resource.messages ?? []).sorted { $0.date < $1.date }

        // Trashed messages are hidden unless the whole thread is in the Trash,
        // and an unsent reply is hidden unless the thread is nothing but drafts.
        var shown = all.filter { !$0.has("TRASH") }
        let isTrashed = shown.isEmpty
        if isTrashed {
            shown = all
        }
        let delivered = shown.filter { !$0.has("DRAFT") }
        let isDraft = delivered.isEmpty
        if !isDraft {
            shown = delivered
        }
        guard let first = shown.first, let latest = shown.last else { return nil }

        let folder: Mailbox =
            if isTrashed {
                .trash
            } else if isDraft {
                .drafts
            } else if shown.contains(where: { $0.has("INBOX") }) {
                .inbox
            } else if shown.allSatisfy({ $0.has("SENT") }) {
                .sent
            } else {
                .archive
            }

        let applied = Set(shown.flatMap { $0.labelIds ?? [] })
        let subject = EncodedWord.decode(first.header("Subject") ?? "").trimmingCharacters(in: .whitespaces)
        let thread = MailThread(
            id: resource.id,
            subject: subject.isEmpty ? "No Subject" : subject,
            messages: shown.map(message),
            labelIDs: labels.map(\.id).filter(applied.contains),
            folder: folder,
            isUnread: applied.contains("UNREAD"),
            isStarred: applied.contains("STARRED"),
            hasSentMessages: delivered.contains { $0.has("SENT") },
            categories: Set(applied.compactMap(InboxCategory.init(labelID:)))
        )
        let anchor = ReplyAnchor(
            latestMessageID: latest.id,
            messageID: latest.header("Message-ID"),
            references: latest.header("References")
        )
        return MappedThread(thread: thread, anchor: anchor)
    }

    private func message(from resource: GmailResource.Message) -> Message {
        let text = QuotedText.split(MessageContent.text(of: resource.payload))
        let sender = contacts(resource.header("From")).first ?? Contact(name: "", email: "")
        return Message(
            id: resource.id,
            sender: sender,
            to: contacts(resource.header("To")),
            cc: contacts(resource.header("Cc")),
            date: resource.date,
            body: text.body,
            quoted: text.quoted,
            attachments: MessageContent.attachments(of: resource.payload, messageID: resource.id),
            html: MessageContent.designedHTML(of: resource.payload),
            snippet: resource.snippet.map { HTMLText.decodingEntities(in: $0).trimmingCharacters(in: .whitespaces) },
            unsubscribe: sender == account ? nil : Unsubscribe(
                list: resource.header("List-Unsubscribe"),
                post: resource.header("List-Unsubscribe-Post")
            ),
            inlineImages: MessageContent.inlineImages(of: resource.payload, messageID: resource.id)
        )
    }

    /// The people in a header, with the account's own address shown as the account.
    private func contacts(_ header: String?) -> [Contact] {
        AddressList.contacts(in: header).map { $0.email == account.email ? account : $0 }
    }
}
