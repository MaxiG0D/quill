import SwiftUI

/// The text of a message, its quoted text behind a toggle, and its attachments.
struct MessageBody: View {
    let message: Message

    @State private var showsQuoted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(message.body)
                .textRole(.reading)
                .lineSpacing(5)
                .foregroundStyle(Palette.label)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let quoted = message.quoted {
                QuotedTextToggle(isExpanded: $showsQuoted)
                if showsQuoted {
                    Text(quoted)
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

            ForEach(message.attachments) { attachment in
                AttachmentRow(attachment: attachment) {
                    ShareLink(item: attachment.filename)
                }
                .frame(maxWidth: 340)
            }
        }
    }
}
