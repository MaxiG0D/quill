import SwiftUI

/// The detail column of the wide layout: the open thread on a raised sheet of paper.
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
        .padding([.horizontal, .bottom], Spacing.s)
        .background(Palette.background)
        .animation(Motion.quick, value: thread?.id)
        .navigationTitle("")
        .toolbar {
            SplitToolbar(thread: thread, store: store, router: router)
        }
    }

    private var thread: MailThread? {
        store.thread(store.selectedThreadID)
    }
}
