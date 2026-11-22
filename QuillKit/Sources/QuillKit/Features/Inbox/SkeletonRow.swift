import SwiftUI

/// A placeholder row that pulses while mail loads.
struct SkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            RoundedRectangle(cornerRadius: 40 * Radius.squircle, style: .continuous)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Capsule().frame(width: 140, height: 12)
                Capsule().frame(height: 10)
                Capsule().frame(height: 10).padding(.trailing, 60)
            }
            .padding(.top, 2)
        }
        .foregroundStyle(Palette.fill)
        .modifier(SkeletonPulse(isAnimated: !reduceMotion))
        .accessibilityHidden(true)
    }
}

private struct SkeletonPulse: ViewModifier {
    let isAnimated: Bool

    func body(content: Content) -> some View {
        if isAnimated {
            content.phaseAnimator([0.45, 1.0]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.9)
            }
        } else {
            content.opacity(0.75)
        }
    }
}
