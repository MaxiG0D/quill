import SwiftUI

/// A mailbox or label in the sidebar and the Mailboxes sheet.
struct SidebarRow: View {
    enum Icon {
        case symbol(String)
        case swatch(LabelTone)
    }

    let title: String
    let icon: Icon
    var count: Int?
    let isSelected: Bool
    /// The roomier form used inside the Mailboxes sheet's cards.
    var isCard = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCard ? Spacing.m : Spacing.s) {
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
            .padding(.horizontal, isCard ? Spacing.l : Spacing.s)
            .frame(minHeight: isCard ? 54 : Metrics.target)
            .background(isSelected ? Palette.accentTint : .clear, in: .rect(cornerRadius: isCard ? 0 : Radius.small))
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
                .foregroundStyle(isCard || isSelected ? Palette.accent : Palette.secondaryLabel)
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
        if isSelected && !isCard {
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
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? Palette.accent : Palette.secondaryLabel)
        }
    }
}
