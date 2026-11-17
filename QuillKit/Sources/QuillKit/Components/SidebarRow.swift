import SwiftUI

/// A mailbox or label in the sidebar and the mailboxes drawer.
struct SidebarRow: View {
    enum Icon {
        case symbol(String)
        case swatch(LabelTone)
    }

    let title: String
    let icon: Icon
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                iconView
                    .frame(width: 24)
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(Palette.label)
                    .lineLimit(1)
                Spacer(minLength: Spacing.xs)
                if let count {
                    countView(count)
                }
            }
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: Metrics.target)
            .background(isSelected ? Palette.accentTint : .clear, in: .rect(cornerRadius: Radius.small))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(Motion.quick, value: isSelected)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .foregroundStyle(isSelected ? Palette.accent : Palette.secondaryLabel)
                .accessibilityHidden(true)
        case .swatch(let tone):
            RoundedRectangle(cornerRadius: 4)
                .fill(tone.fill)
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func countView(_ count: Int) -> some View {
        if isSelected {
            Text(count, format: .number)
                .textRole(.meta)
                .fontWeight(.bold)
                .foregroundStyle(Palette.onFill)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Palette.accentFill, in: .capsule)
        } else {
            Text(count, format: .number)
                .font(.callout.monospacedDigit())
                .foregroundStyle(Palette.secondaryLabel)
        }
    }
}
