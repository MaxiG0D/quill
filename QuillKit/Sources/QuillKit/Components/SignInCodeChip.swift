import SwiftUI

/// A sign-in code at the top of a message. Tapping it copies the digits.
struct SignInCodeChip: View {
    let code: SignInCode

    @State private var copied = 0

    var body: some View {
        Button {
            CodeCopying.copy(code.digits)
            copied += 1
        } label: {
            HStack(spacing: Spacing.s) {
                Text(code.display)
                    .font(.title2.weight(.semibold).monospacedDigit())
                Image(systemName: copied > 0 ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(Palette.accentTint, in: .capsule)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: copied)
        .accessibilityLabel("Copy code \(code.digits)")
    }
}
