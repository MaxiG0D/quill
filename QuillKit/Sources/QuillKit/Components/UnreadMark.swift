import SwiftUI

/// The small rotated square that marks unread mail.
struct UnreadMark: View {
    #if os(macOS)
    @ScaledMetric(relativeTo: .callout) private var size = 6.5
    #else
    @ScaledMetric(relativeTo: .callout) private var size = 8.0
    #endif

    private var box: Double { size * 1.45 }

    var body: some View {
        let baselineOffset = size * 0.45
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Palette.accent)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
            .frame(width: box, height: box)
            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + baselineOffset }
            .accessibilityHidden(true)
    }
}
