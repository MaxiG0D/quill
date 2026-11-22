import SwiftUI

/// A compact attachment chip shown on pinned cards and inbox rows.
struct AttachmentChip: View {
    let attachment: Attachment
    var extraCount = 0
    var isCompact = false
    var onTint = false
    var isLoading = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let onTap {
            Button(action: onTap) {
                chipBody
            }
            .buttonStyle(.pressable)
            .disabled(isLoading)
            .help("Preview \(attachment.filename)")
        } else {
            chipBody
        }
    }

    private var chipBody: some View {
        HStack(spacing: isCompact ? Spacing.xxs + 2 : Spacing.xs) {
            ZStack {
                AttachmentGlyph(kind: attachment.kind, size: isCompact ? 20 : 26)
                    .opacity(isLoading ? 0.25 : 1)
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            Text(attachment.filename)
                .font(isCompact ? .caption : .subheadline)
                .fontWeight(isCompact ? .medium : .regular)
                .foregroundStyle(Palette.label)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: isCompact ? 148 : nil, alignment: .leading)
            if extraCount > 0 {
                Text("+\(extraCount)")
                    .textRole(.meta)
                    .foregroundStyle(Palette.secondaryLabel)
                    .fixedSize()
            }
        }
        .padding(.leading, isCompact ? 4 : 5)
        .padding(.trailing, isCompact ? Spacing.xs : Spacing.s)
        .padding(.vertical, isCompact ? 3 : 5)
        .background(background, in: .rect(cornerRadius: isCompact ? 8 : Radius.small, style: .continuous))
        .overlay {
            if isCompact {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Palette.separator.opacity(0.7), lineWidth: Metrics.hairline)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityTitle)
    }

    private var background: Color {
        if isCompact {
            return onTint ? Palette.surface : Palette.fill
        }
        return Palette.surface
    }

    private var accessibilityTitle: String {
        if extraCount > 0 {
            "Attachment, \(attachment.filename), and \(extraCount) more"
        } else {
            "Attachment, \(attachment.filename)"
        }
    }
}
