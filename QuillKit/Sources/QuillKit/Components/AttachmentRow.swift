import SwiftUI

/// A bordered attachment with a menu of things to do with the file.
struct AttachmentRow<Actions: View>: View {
    let attachment: Attachment
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(spacing: Spacing.s) {
            AttachmentGlyph(kind: attachment.kind)
            Text(attachment.filename)
                .font(.callout)
                .foregroundStyle(Palette.label)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Menu("More", systemImage: "ellipsis") {
                actions
            }
            .labelStyle(.iconOnly)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .foregroundStyle(Palette.secondaryLabel)
            .frame(minWidth: Metrics.target, minHeight: Metrics.target)
            .contentShape(.rect)
        }
        .padding(.leading, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(Palette.background.opacity(0.6), in: .rect(cornerRadius: Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium)
                .strokeBorder(Palette.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Attachment, \(attachment.filename)")
    }
}
