import SwiftUI

/// The rounded square of an app icon, with corners that scale with its size.
struct IconShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: min(rect.width, rect.height) * Radius.icon, style: .continuous)
            .path(in: rect)
    }
}
