import SwiftUI

/// A serif header for a group of threads. Pinned carries a pin glyph.
struct SectionHeader: View {
    let kind: ThreadSection.Kind

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if kind == .pinned {
                Image(systemName: "pin")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
            }
            Text(kind.title)
                .textRole(.section)
                .foregroundStyle(Palette.label)
        }
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }
}
