import SwiftUI

/// A designed message, drawn as its sender laid it out and as tall as its content.
struct HTMLMessageView: View {
    let html: String

    @State private var height = 240.0
    @State private var width = 0.0

    var body: some View {
        MessageWebView(html: html, width: width, height: $height)
            .frame(height: height)
            .clipShape(.rect(cornerRadius: Radius.medium))
            .onGeometryChange(for: Double.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            .accessibilityLabel("Message")
    }
}
