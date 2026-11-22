import SwiftUI

/// The empty state: a large serif zero with a disc resting on its shoulder.
struct InboxZero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var size = 250.0
    var message: String? = nil
    var accessibilityTitle = "No mail"

    var body: some View {
        VStack(spacing: Spacing.s) {
            Text(verbatim: "0")
                .font(.system(size: size, weight: .medium, design: .serif).italic())
                .foregroundStyle(Palette.accent)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Palette.label)
                        .frame(width: size * 0.17, height: size * 0.17)
                        .offset(x: size * 0.02, y: size * 0.13)
                        .offset(y: hasAppeared || reduceMotion ? 0 : -size * 0.5)
                        .opacity(hasAppeared || reduceMotion ? 1 : 0)
                }
            if let message {
                Text(message)
                    .textRole(.section)
                    .foregroundStyle(Palette.secondaryLabel)
            }
        }
        .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.92)
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message ?? accessibilityTitle)
        .onAppear(perform: appear)
    }

    private func appear() {
        if reduceMotion {
            hasAppeared = true
        } else {
            withAnimation(.spring(duration: 0.7, bounce: 0.35).delay(0.1)) {
                hasAppeared = true
            }
        }
    }
}

#Preview {
    InboxZero()
        .background(Palette.background)
}
