import SwiftUI

/// Directions to an upcoming event's address, right on its inbox row.
struct DirectionsChip: View {
    let address: MailAddress
    /// True when rendered on `Palette.accentTint` (selected row or pinned card).
    var onTint = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = MapsApp.current.url(for: address.full, directions: true) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .imageScale(.small)
                Text("Directions")
            }
            .textRole(.chip)
            .lineLimit(1)
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 3)
            .background(onTint ? Palette.surface : Palette.accentTint, in: .capsule)
        }
        .buttonStyle(.pressable)
        .help(address.full)
        .accessibilityLabel("Directions to \(address.full)")
    }
}
