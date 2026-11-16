import SwiftUI

/// A designed message, drawn as its sender laid it out and as tall as its content.
///
/// The message appears once, whole: it stays hidden while its pictures load, then fades in
/// at its final height.
struct HTMLMessageView: View {
    let html: String

    @State private var height = 240.0
    @State private var width = 0.0
    @State private var isReady = false

    var body: some View {
        MessageWebView(html: html, width: width, height: $height, isReady: $isReady)
            .opacity(isReady ? 1 : 0)
            .frame(height: height)
            .background {
                if !isReady {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                }
            }
            .clipShape(.rect(cornerRadius: Radius.medium))
            .animation(Motion.scene, value: isReady)
            // Before the message shows, its height is set without ceremony. After, a late picture eases it open.
            .animation(isReady ? Motion.scene : nil, value: height)
            .onGeometryChange(for: Double.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            .accessibilityLabel("Message")
    }
}
