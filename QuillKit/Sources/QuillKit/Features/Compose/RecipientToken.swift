import SwiftUI

/// A recipient in the To or Cc field. Tap to select it, tap again to remove it.
struct RecipientToken: View {
    let contact: Contact
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .frame(width: 24, height: 24)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    MonogramAvatar(contact, size: .small)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(contact.displayName)
                    .font(.callout)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Palette.onFill : Palette.label)
            .padding(.leading, Spacing.xxs)
            .padding(.trailing, Spacing.s)
            .padding(.vertical, Spacing.xxs)
            .background(isSelected ? Palette.accentFill : contact.tone.fill, in: .rect(cornerRadius: Radius.small))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(contact.displayName)
        .accessibilityHint(isSelected ? "Removes this recipient" : "Selects this recipient")
    }
}
