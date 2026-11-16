import SwiftUI

/// The round close button in the corner of a sheet's header.
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Close", systemImage: "xmark")
                .labelStyle(.iconOnly)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.secondaryLabel)
                .frame(width: 32, height: 32)
                .background(Palette.fill, in: .circle)
                .frame(minWidth: Metrics.target, minHeight: Metrics.target, alignment: .trailing)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }
}
