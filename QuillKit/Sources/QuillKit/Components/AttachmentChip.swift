import SwiftUI

/// The compact attachment shown on a pinned card.
struct AttachmentChip: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: Spacing.xs) {
            AttachmentGlyph(kind: attachment.kind, size: 26)
            Text(attachment.filename)
                .font(.subheadline)
                .foregroundStyle(Palette.label)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.leading, 5)
        .padding(.trailing, Spacing.s)
        .padding(.vertical, 5)
        .background(Palette.surface, in: .rect(cornerRadius: Radius.small))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Attachment, \(attachment.filename)")
    }
}
