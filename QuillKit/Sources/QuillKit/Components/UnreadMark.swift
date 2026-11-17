import SwiftUI

/// The small rotated square that marks unread mail.
struct UnreadMark: View {
    @ScaledMetric(relativeTo: .callout) private var size = 10.0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Palette.accent)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }
}
