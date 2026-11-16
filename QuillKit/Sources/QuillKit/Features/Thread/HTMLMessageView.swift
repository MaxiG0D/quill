import SwiftUI

/// A designed message, drawn as its sender laid it out and as tall as its content.
///
/// The message fades in as soon as its layout is settled, and its height eases if a late
/// picture changes it.
struct HTMLMessageView: View {
    let html: String

    @State private var height = 240.0
    @State private var width = 0.0
    @State private var isReady = false
    /// Set when the message is taking long enough that the wait should be acknowledged.
    @State private var isSlow = false

    var body: some View {
        MessageWebView(html: html, width: width, height: $height, isReady: $isReady)
            .opacity(isReady ? 1 : 0)
            .frame(height: height)
            .background {
                if isSlow && !isReady {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                }
            }
            .clipShape(.rect(cornerRadius: Radius.medium))
            .animation(Motion.scene, value: isReady)
            .animation(Motion.scene, value: isSlow)
            .task {
                try? await Task.sleep(for: .milliseconds(400))
                isSlow = true
            }
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
