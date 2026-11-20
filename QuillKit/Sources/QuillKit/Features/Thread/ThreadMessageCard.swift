import SwiftUI

/// One message in a conversation. Collapsed it is a single line, expanded it shows everything.
struct ThreadMessageCard: View {
    let message: Message
    let threadID: MailThread.ID
    var subject = ""
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                Button(action: toggle) {
                    MessageHeader(message: message, isExpanded: isExpanded)
                }
                .buttonStyle(.plain)
                if isExpanded, message.unsubscribe != nil {
                    UnsubscribeButton(message: message, threadID: threadID)
                }
            }

            if isExpanded {
                MessageBody(message: message, subject: subject)
                    .transition(.opacity)
            }
        }
        .padding(isExpanded ? Spacing.l : Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: Radius.large))
    }
}
