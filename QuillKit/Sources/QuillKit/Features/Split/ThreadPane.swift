import SwiftUI

/// The detail column of the wide layout: the open thread on a floating card.
struct ThreadPane: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if let thread {
                ThreadDocument(thread: thread)
                    .id(thread.id)
                    .transition(.opacity)
            } else {
                AppMark(size: 48)
                    .saturation(0)
                    .opacity(0.09)
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
        .clipShape(card)
        .overlay {
            card.strokeBorder(borderColor, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 6, y: 1)
        .padding(Self.inset)
        .background(Palette.background)
        .animation(Motion.quick, value: thread?.id)
        .navigationTitle("")
        .toolbar {
            SplitToolbar(thread: thread, store: store, router: router)
        }
    }

    #if os(macOS)
    private static let inset = 8.0
    private static let radius = 10.0
    #else
    private static let inset = 12.0
    private static let radius = 16.0
    #endif

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
    }

    private var borderColor: Color {
        colorScheme == .dark ? .white.opacity(0.05) : Palette.separator.opacity(0.5)
    }

    private var thread: MailThread? {
        store.thread(store.selectedThreadID)
    }
}
