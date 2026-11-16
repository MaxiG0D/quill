import SwiftUI

/// An icon-only button with a full-size hit target and a spoken title.
struct IconButton: View {
    let title: String
    let systemImage: String
    var width = Metrics.target
    var height = Metrics.target
    let action: () -> Void

    init(_ title: String, systemImage: String, width: Double = Metrics.target, height: Double = Metrics.target, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.width = width
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(minWidth: width, minHeight: height)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }
}
