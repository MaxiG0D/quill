import SwiftUI

/// One message in a conversation. Collapsed it is a single line, expanded it shows everything.
struct ThreadMessageCard: View {
    let message: Message
    var subject = ""
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Button(action: toggle) {
                MessageHeader(message: message, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

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
