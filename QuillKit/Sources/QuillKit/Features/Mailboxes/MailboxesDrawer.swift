import SwiftUI

/// The compact layout's sidebar: mailboxes, labels and the account, sliding in from
/// the leading edge over a dimmed mailbox.
private struct MailboxesDrawer: ViewModifier {
    @Binding var isPresented: Bool

    @GestureState(resetTransaction: Transaction(animation: Motion.scene)) private var pull = 0.0

    private static let width = 320.0
    /// The strip of mailbox left showing, wide enough to tap.
    private static let gap = 64.0

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack(alignment: .leading) {
                    if isPresented {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture(perform: close)
                            .accessibilityHidden(true)
                            .transition(.opacity)
                        SidebarView(onSelect: close)
                            // Starts the mailboxes level with the mailbox title behind them.
                            .contentMargins(.top, Spacing.xxl, for: .scrollContent)
                            .frame(maxWidth: Self.width)
                            .background(.regularMaterial, ignoresSafeAreaEdges: .all)
                            .offset(x: pull)
                            .padding(.trailing, Self.gap)
                            .simultaneousGesture(drag)
                            .accessibilityAddTraits(.isModal)
                            .accessibilityAction(.escape, close)
                            .transition(.move(edge: .leading))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .animation(Motion.scene, value: isPresented)
            }
    }

    /// Follows a pull toward the leading edge and closes once it has gone far enough.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 16)
            .updating($pull) { value, pull, _ in
                pull = min(0, value.translation.width)
            }
            .onEnded { value in
                if value.translation.width < -80 || value.predictedEndTranslation.width < -200 {
                    close()
                }
            }
    }

    private func close() {
        isPresented = false
    }
}

extension View {
    /// Presents the mailboxes drawer over this view.
    func mailboxesDrawer(isPresented: Binding<Bool>) -> some View {
        modifier(MailboxesDrawer(isPresented: isPresented))
    }
}

#Preview {
    Color.clear
        .mailboxesDrawer(isPresented: .constant(true))
        .environment(MailStore(snapshot: SampleData.snapshot(now: .now)))
        .environment(Router())
}
