import SwiftUI

/// The detail column of the wide layout: the open thread on a square reading surface that
/// fills the column edge to edge.
struct ThreadPane: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        ZStack {
            if let thread {
                ThreadDocument(thread: thread)
                    .id(thread.id)
                    .transition(.opacity)
            } else {
                AppMark(size: 88)
                    .opacity(0.5)
                    .padding(.bottom, 32)
                    .transition(.opacity)
                    .accessibilityElement()
                    .accessibilityLabel("No conversation selected")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { ReadingSlab(tinted: thread != nil) }
        .animation(Motion.quick, value: thread?.id)
        .navigationTitle("")
        #if os(iOS)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        // Compose floats in the screen's bottom-right corner (see BottomRow); the thread's
        // last lines scroll clear of it.
        .contentMargins(.bottom, BottomRow.height, for: .scrollContent)
        #endif
        .toolbar {
            SplitToolbar(thread: thread, store: store, router: router)
        }
    }

    private var thread: MailThread? {
        store.thread(store.selectedThreadID)
    }
}

/// The reading surface: square and edge to edge, so scrolling text is never cut by a
/// curve. The list beside it is separated by the split view's divider and the tone step.
private struct ReadingSlab: View {
    var tinted: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Palette.surface
            LinearGradient(
                colors: [Palette.accentTint, Palette.accentTint.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 240)
            .opacity(tinted ? 1 : 0)
        }
        .ignoresSafeArea()
    }
}
