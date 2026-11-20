import SwiftUI

/// The compact layout's conversation: the subject, then each message as a card.
struct ThreadConversation: View {
    let thread: MailThread

    @State private var expansion: MessageExpansion

    init(thread: MailThread) {
        self.thread = thread
        _expansion = State(initialValue: MessageExpansion(thread: thread))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ThreadHeading(thread: thread)
                    .padding(.horizontal, Spacing.xxs)
                    .padding(.bottom, Spacing.xs)
                ForEach(thread.messages) { message in
                    ThreadMessageCard(
                        message: message,
                        threadID: thread.id,
                        subject: thread.subject,
                        isExpanded: expansion.contains(message)
                    ) {
                        toggle(message)
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: Metrics.readingWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: thread.messages.count) {
            withAnimation(Motion.expand) {
                expansion.expandLatest(of: thread)
            }
        }
    }

    private func toggle(_ message: Message) {
        withAnimation(Motion.expand) {
            expansion.toggle(message)
        }
    }
}
