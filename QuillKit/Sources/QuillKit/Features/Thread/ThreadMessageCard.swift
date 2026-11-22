import SwiftUI

/// One message in a conversation. Collapsed it is a single line, expanded it shows everything.
struct ThreadMessageCard: View {
    let message: Message
    let thread: MailThread
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            MessageHeader(
                message: message,
                thread: thread,
                isExpanded: isExpanded,
                onToggle: toggle
            )

            if isExpanded {
                MessageBody(message: message, subject: thread.subject)
                    .transition(.opacity)
            }
        }
        .padding(isExpanded ? Spacing.l : Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: Radius.large))
    }
}
