import SwiftUI

/// The compact layout's sidebar: mailboxes, labels and the account, sliding in from
/// the leading edge over a dimmed mailbox.
private struct MailboxesDrawer: ViewModifier {
    @Binding var isPresented: Bool

    @GestureState(resetTransaction: Transaction(animation: Motion.scene)) private var pull = Pull()

    /// A drag on the drawer. Its direction is settled by its first movement, so
    /// scrolling the mailboxes never slides the drawer sideways.
    private struct Pull {
        var isSideways: Bool?
        var offset = 0.0
    }

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
                            .offset(x: pull.offset)
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
                let isSideways = pull.isSideways ?? Self.isSideways(value.translation)
                pull.isSideways = isSideways
                pull.offset = isSideways ? min(0, value.translation.width) : 0
            }
            .onEnded { value in
                guard Self.isSideways(value.translation) else { return }
                if value.translation.width < -80 || value.predictedEndTranslation.width < -200 {
                    close()
                }
            }
    }

    private static func isSideways(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
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
