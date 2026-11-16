import SwiftUI

/// A placeholder row that pulses while mail loads.
struct SkeletonRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            RoundedRectangle(cornerRadius: 40 * Radius.squircle)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Capsule().frame(width: 140, height: 12)
                Capsule().frame(height: 10)
                Capsule().frame(height: 10).padding(.trailing, 60)
            }
            .padding(.top, 2)
        }
        .foregroundStyle(Palette.fill)
        .phaseAnimator([0.45, 1.0]) { content, opacity in
            content.opacity(opacity)
        } animation: { _ in
            .easeInOut(duration: 0.9)
        }
        .accessibilityHidden(true)
    }
}
