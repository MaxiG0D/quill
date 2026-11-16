import PhotosUI
import SwiftUI

/// The composer's bottom bar: text style, bold, italic and list on the left,
/// photo and file attachments on the right.
struct FormatBar: View {
    @Binding var photo: PhotosPickerItem?
    let onStyle: (ComposeTextStyle) -> Void
    let onBold: () -> Void
    let onItalic: () -> Void
    let onList: () -> Void
    let onAttach: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Menu {
                ForEach(ComposeTextStyle.allCases) { style in
                    Button(style.title) {
                        onStyle(style)
                    }
                }
            } label: {
                Label("Text Style", systemImage: "textformat.size")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: Metrics.target, minHeight: Metrics.target)
                    .contentShape(.rect)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            IconButton("Bold", systemImage: "bold", action: onBold)
            IconButton("Italic", systemImage: "italic", action: onItalic)
            IconButton("List", systemImage: "list.bullet", action: onList)
            Spacer()
            Group {
                PhotosPicker(selection: $photo, matching: .images) {
                    Label("Add Photo", systemImage: "photo")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: Metrics.target, minHeight: Metrics.target)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                IconButton("Attach File", systemImage: "paperclip", action: onAttach)
            }
            .foregroundStyle(Palette.accent)
        }
        .font(.body.weight(.medium))
        .foregroundStyle(Palette.label)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xxs)
        .background(Palette.surface)
        .overlay(alignment: .top) {
            Palette.separator.frame(height: Metrics.hairline)
        }
    }
}
