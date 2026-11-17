import SwiftUI

/// The detail column of the wide layout: the open thread on a raised sheet of paper.
struct ThreadPane: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    @State private var topInset = 0.0

    /// The tallest top inset that is plain margin. Anything taller is a bar.
    private static let marginLimit = 30.0

    var body: some View {
        ZStack {
            if let thread {
                ThreadDocument(thread: thread)
                    .id(thread.id)
                    .transition(.opacity)
            } else {
                AppMark(size: 72)
                    .saturation(0)
                    .opacity(0.18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Palette.accentTint, Palette.accentTint.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 170)
            .opacity(thread == nil ? 0 : 1)
        }
        .background(Palette.surface)
        .clipShape(.rect(cornerRadius: Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large)
                .strokeBorder(Palette.separator, lineWidth: 1)
        }
        .padding(.horizontal, Spacing.s)
        .padding(.bottom, bottomMargin)
        .reachesBottomEdge()
        .background(Palette.background)
        .onGeometryChange(for: Double.self) { proxy in
            proxy.safeAreaInsets.top
        } action: { inset in
            topInset = inset
        }
        .animation(Motion.quick, value: thread?.id)
        .navigationTitle("")
        .toolbar {
            SplitToolbar(thread: thread, store: store, router: router)
        }
    }

    private var thread: MailThread? {
        store.thread(store.selectedThreadID)
    }

    /// Matches the margin above the page when no bar sits there, as on an unfolded
    /// iPhone Duo, so the page is centered beside its toolbar.
    private var bottomMargin: Double {
        topInset < Self.marginLimit ? max(Spacing.s, topInset) : Spacing.s
    }
}

private extension View {
    /// Lets the page run past the home indicator on iOS, so its margins are its own.
    @ViewBuilder
    func reachesBottomEdge() -> some View {
        #if os(iOS)
        self.ignoresSafeArea(.container, edges: .bottom)
        #else
        self
        #endif
    }
}
