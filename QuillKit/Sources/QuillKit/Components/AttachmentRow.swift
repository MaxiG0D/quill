import SwiftUI

/// A bordered attachment with a menu of things to do with the file.
struct AttachmentRow<Actions: View>: View {
    let attachment: Attachment
    var isLoading = false
    var onOpen: (() -> Void)? = nil
    @ViewBuilder let actions: Actions

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Spacing.s) {
            if let onOpen {
                Button(action: onOpen) {
                    labelContent
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .help("Preview \(attachment.filename)")
            } else {
                labelContent
            }
            Menu("Actions for \(attachment.filename)", systemImage: "ellipsis") {
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
        .padding(.trailing, Spacing.xxs)
        .padding(.vertical, Spacing.xxs)
        .background(isHovering ? Palette.fill : Palette.background.opacity(0.6), in: .rect(cornerRadius: Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium)
                .strokeBorder(Palette.separator, lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .animation(Motion.quick, value: isHovering)
        .accessibilityElement(children: .contain)
    }

    private var labelContent: some View {
        HStack(spacing: Spacing.s) {
            ZStack {
                AttachmentGlyph(kind: attachment.kind)
                    .opacity(isLoading ? 0.25 : 1)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.filename)
                    .font(.callout)
                    .foregroundStyle(Palette.label)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let sizeText {
                    Text(sizeText)
                        .textRole(.meta)
                        .foregroundStyle(Palette.secondaryLabel)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(.rect)
    }

    private var sizeText: String? {
        guard attachment.byteCount > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file)
    }
}
