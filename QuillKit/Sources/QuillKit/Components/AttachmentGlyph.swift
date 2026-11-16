import SwiftUI

/// A small tile with the file type in capitals: PDF, JPG or DOC.
struct AttachmentGlyph: View {
    let kind: AttachmentKind
    var size = 36.0

    var body: some View {
        Text(kind.badge)
            .font(.system(size: size * 0.3, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(kind.tone.ink)
            .frame(width: size, height: size)
            .background(kind.tone.fill, in: .rect(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}
