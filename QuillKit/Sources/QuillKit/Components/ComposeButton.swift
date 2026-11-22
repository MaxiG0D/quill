import SwiftUI

/// The warm square button that starts a new message.
struct ComposeButton: View {
    var size = 54.0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Compose", systemImage: "square.and.pencil")
                .labelStyle(.iconOnly)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(Palette.onFill)
                .frame(width: size, height: size)
                .background(Palette.warmFill, in: .rect(cornerRadius: size * Radius.squircle, style: .continuous))
                .shadow(color: Palette.warmFill.opacity(0.3), radius: 10, y: 4)
                .contentShape(.rect(cornerRadius: size * Radius.squircle, style: .continuous))
        }
        .buttonStyle(.pressable)
        .help("New Message")
    }
}
