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

    @State private var isHovering = false

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
            .background(rowBackground, in: .rect(cornerRadius: Radius.small))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(Motion.quick, value: isSelected)
        .animation(Motion.quick, value: isHovering)
    }

    private var rowBackground: Color {
        if isSelected { return Palette.accentTint }
        return isHovering ? Palette.fill : .clear
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .foregroundStyle(isSelected ? Palette.accent : Palette.secondaryLabel)
                .accessibilityHidden(true)
        case .swatch(let tone):
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(tone.fill)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(tone.ink, lineWidth: 1.5)
                }
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
                .textRole(.meta)
                .foregroundStyle(Palette.secondaryLabel)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
        }
    }
}
