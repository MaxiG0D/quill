import SwiftUI

/// The small ellipsis pill that shows or hides quoted text.
struct QuotedTextToggle: View {
    @Binding var isExpanded: Bool

    var body: some View {
        Button(action: toggle) {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.secondaryLabel)
                .padding(.horizontal, Spacing.s)
                .frame(height: 20)
                .background(Palette.fill, in: .capsule)
                .frame(minHeight: Metrics.target, alignment: .center)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(isExpanded ? "Hide quoted text" : "Show quoted text")
    }

    private func toggle() {
        withAnimation(Motion.expand) {
            isExpanded.toggle()
        }
    }
}
