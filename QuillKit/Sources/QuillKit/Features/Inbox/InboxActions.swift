import SwiftUI

/// Search and Compose, kept within the thumb's reach: side by side at the foot of the
/// screen, or stacked when the device offers a strip beside the content.
struct InboxActions: View {
    enum Arrangement {
        case row
        case stack
    }

    var arrangement = Arrangement.row
    var size = 54.0
    let search: () -> Void
    let compose: () -> Void

    var body: some View {
        let layout = arrangement == .row
            ? AnyLayout(HStackLayout(spacing: Spacing.s))
            : AnyLayout(VStackLayout(spacing: Spacing.s))
        layout {
            Button(action: search) {
                Label("Search", systemImage: "magnifyingglass")
                    .labelStyle(.iconOnly)
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundStyle(Palette.accent)
                    .frame(width: size, height: size)
                    .background(Palette.surface, in: .circle)
                    .overlay {
                        Circle().strokeBorder(Palette.separator, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            }
            .buttonStyle(.pressable)
            ComposeButton(size: size, action: compose)
        }
    }
}

#Preview {
    InboxActions(search: {}, compose: {})
        .padding()
}
