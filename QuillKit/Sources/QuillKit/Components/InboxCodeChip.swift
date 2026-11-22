import SwiftUI

/// A compact 1-tap sign-in code pill shown right on an inbox row so codes can be copied without opening the email.
struct InboxCodeChip: View {
    let code: SignInCode
    var onTint = false

    @State private var copied = 0
    @State private var isCopied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "key.fill")
                    .font(.caption2.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(isCopied ? "Copied \(code.display)" : code.display)
                    .textRole(.chip)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 3)
            .background(onTint ? Palette.surface : Palette.accentTint, in: .capsule)
        }
        .buttonStyle(.pressable)
        .help("Copy verification code")
        .sensoryFeedback(.success, trigger: copied)
        .accessibilityLabel("Copy code \(code.digits.map(String.init).joined(separator: " "))")
        .accessibilityValue(isCopied ? "Copied" : "")
        .onDisappear { resetTask?.cancel() }
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
