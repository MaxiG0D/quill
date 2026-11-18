import SwiftUI

/// A message's content, as designed HTML or as text, and its attachments.
struct MessageBody: View {
    let message: Message
    /// The conversation's subject, read with the message to find events.
    var subject = ""

    @State private var showsQuoted = false

    /// The message as text, with anything it quotes behind a toggle.
    @ViewBuilder
    private var text: some View {
        Text(LinkedText.make(message.body))
            .textRole(.reading)
            .lineSpacing(5)
            .foregroundStyle(Palette.label)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)

        if let quoted = message.quoted {
            QuotedTextToggle(isExpanded: $showsQuoted)
            if showsQuoted {
                Text(LinkedText.make(quoted))
                    .font(.callout)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.secondaryLabel)
                    .textSelection(.enabled)
                    .padding(.leading, Spacing.s)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Palette.accentTint)
                            .frame(width: 3)
                    }
                    .padding(.bottom, Spacing.xs)
                    .transition(.opacity)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let code = SignInCode.find(in: message.body.isEmpty ? message.snippet ?? "" : message.body) {
                SignInCodeChip(code: code)
                    .padding(.bottom, Spacing.xs)
            }
            if let event = MailEventCache.event(in: message, subject: subject), event.isUpcoming(at: .now) {
                EventCard(
                    event: event,
                    details: EventDetails.make(
                        title: EventCalendar.title(subject: subject, sender: message.sender.displayName),
                        sender: message.sender.displayName,
                        text: message.body.isEmpty ? message.snippet ?? "" : message.body
                    ),
                    messageID: message.id
                )
                .padding(.bottom, Spacing.xs)
            }
            if let html = message.html {
                HTMLMessageView(html: html)
            } else {
                text.tint(Palette.link)
            }

            ForEach(message.attachments) { attachment in
                AttachmentRow(attachment: attachment) {
                    ShareLink(item: attachment.filename)
                }
                .frame(maxWidth: 340)
            }
        }
    }
}
