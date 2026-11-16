import SwiftUI

/// One icon in the picker, ringed when it is the current choice.
struct AppIconTile: View {
    let icon: AppIcon
    let isSelected: Bool

    var body: some View {
        Image(icon.previewName, bundle: .module)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .clipShape(IconShape())
            .overlay {
                IconShape()
                    .stroke(Palette.separator, lineWidth: Metrics.hairline)
            }
            .overlay {
                IconShape()
                    .stroke(Palette.accent, lineWidth: 2.5)
                    .padding(-4)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(maxWidth: 72)
            .animation(Motion.quick, value: isSelected)
    }
}

#Preview {
    HStack(spacing: Spacing.s) {
        AppIconTile(icon: .forest, isSelected: true)
        AppIconTile(icon: .paper, isSelected: false)
    }
    .padding()
}
