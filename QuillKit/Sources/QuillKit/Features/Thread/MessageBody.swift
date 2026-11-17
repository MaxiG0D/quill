import SwiftUI

/// A message's content, as designed HTML or as text, and its attachments.
struct MessageBody: View {
    let message: Message

    @State private var showsQuoted = false

    /// The message as text, with anything it quotes behind a toggle.
    @ViewBuilder
    private var text: some View {
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let code = SignInCode.find(in: message.body.isEmpty ? message.snippet ?? "" : message.body) {
                SignInCodeChip(code: code)
                    .padding(.bottom, Spacing.xs)
            }
            if let html = message.html {
                HTMLMessageView(html: html)
            } else {
                text
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
