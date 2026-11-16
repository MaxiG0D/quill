import SwiftUI

/// Quill's mark: a sealed envelope with a dot of ink, shown where no thread is open.
struct AppMark: View {
    var size = 38.0

    var body: some View {
        RoundedRectangle(cornerRadius: size * Radius.squircle)
            .fill(Palette.accentFill)
            .overlay {
                EnvelopeFlap()
                    .fill(.white.opacity(0.16))
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.22, height: size * 0.22)
                    .padding(size * 0.2)
            }
            .clipShape(.rect(cornerRadius: size * Radius.squircle))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    AppMark(size: 120)
        .padding()
}
