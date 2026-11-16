import SwiftUI

/// The composer's top bar: Cancel, the title, and the round Send button.
struct ComposeHeader: View {
    let title: String
    let canSend: Bool
    let isSending: Bool
    let onCancel: () -> Void
    let onSend: () -> Void

    var body: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.body)
                .foregroundStyle(Palette.accent)
                .frame(minHeight: Metrics.target)
                .contentShape(.rect)
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button(action: onSend) {
                Group {
                    if isSending {
                        ProgressView()
                            .tint(Palette.onFill)
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.semibold))
                    }
                }
                .foregroundStyle(Palette.onFill)
                .frame(width: 36, height: 36)
                .background(canSend ? Palette.accentFill : Palette.neutralFill.opacity(0.35), in: .circle)
                .frame(minWidth: Metrics.target, minHeight: Metrics.target, alignment: .trailing)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .disabled(!canSend || isSending)
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityLabel("Send")
            .animation(Motion.quick, value: canSend)
        }
        .overlay {
            Text(title)
                .textRole(.section)
                .foregroundStyle(Palette.label)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.l)
        .padding(.bottom, Spacing.xs)
    }
}
