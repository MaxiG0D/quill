import SwiftUI

/// The wide layout's conversation: one flat page, with rules between messages.
struct ThreadDocument: View {
    let thread: MailThread

    @State private var expansion: MessageExpansion

    init(thread: MailThread) {
        self.thread = thread
        _expansion = State(initialValue: MessageExpansion(thread: thread))
    }

    /// Extra room above the heading at scroll start: below the bar and clear of the slab's
    /// rounded top corners.
    #if os(macOS)
    private static let topClearance = 8.0
    #else
    private static let topClearance = 24.0
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ThreadHeading(thread: thread)
                    .padding(.bottom, Spacing.l)
                Divider().overlay(Palette.separator)
                ForEach(thread.messages) { message in
                    Button {
                        toggle(message)
                    } label: {
                        MessageHeader(
                            message: message,
                            isExpanded: expansion.contains(message),
                            isDetailed: true,
                            isStarred: thread.isStarred
                        )
                        .padding(.vertical, Spacing.m)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Palette.separator)
                    if expansion.contains(message) {
                        MessageBody(message: message, subject: thread.subject)
                            .padding(.vertical, Spacing.xl)
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, Metrics.panePadding)
            .padding(.bottom, Metrics.panePadding)
            .frame(maxWidth: Metrics.readingWidth + Metrics.panePadding * 2, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.top, Self.topClearance, for: .scrollContent)
        .scrollEdgeEffectStyle(.soft, for: .top)
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
