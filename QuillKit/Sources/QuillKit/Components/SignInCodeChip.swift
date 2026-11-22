import SwiftUI

/// A sign-in code at the top of a message. Tapping it copies the digits.
struct SignInCodeChip: View {
    let code: SignInCode

    @State private var copied = 0
    @State private var isCopied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button(action: copy) {
            HStack(spacing: Spacing.s) {
                Text(code.display)
                    .font(.title2.weight(.semibold).monospacedDigit())
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(Palette.accentTint, in: .capsule)
        }
        .buttonStyle(.pressable)
        .help("Copy verification code")
        .sensoryFeedback(.success, trigger: copied)
        .accessibilityLabel("Copy code \(spelledDigits)")
        .accessibilityValue(isCopied ? "Copied" : "")
        .onDisappear { resetTask?.cancel() }
    }

    private var spelledDigits: String {
        code.digits.map(String.init).joined(separator: " ")
    }

    private func copy() {
        CodeCopying.copy(code.digits)
        copied += 1
        withAnimation(Motion.quick) { isCopied = true }
        resetTask?.cancel()
        resetTask = Task {
            await CodeCopying.dismissEverywhere(code.digits)
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.quick) { isCopied = false }
        }
    }
}
