import SwiftUI

/// A designed message, drawn as its sender laid it out and as tall as its content.
///
/// The message fades in as soon as its layout is settled, and its height eases if a late
/// picture changes it. Embedded `cid:` images are resolved inline when present, and in Dark Mode
/// the reader can adapt or restore the message's light paper background.
struct HTMLMessageView: View {
    @Environment(MailStore.self) private var store: MailStore?
    @Environment(\.colorScheme) private var colorScheme

    let html: String
    var inlineImages: [InlineImage] = []

    @State private var height = 240.0
    @State private var width = 0.0
    @State private var isReady = false
    /// Set when the message is taking long enough that the wait should be acknowledged.
    @State private var isSlow = false
    @State private var resolvedHTML: String?
    @State private var overrideDarkMode: Bool?

    private var preferences: MailPreferences { .shared }

    private var isDarkAdapted: Bool {
        guard colorScheme == .dark else { return false }
        return overrideDarkMode ?? preferences.darkModeHTML
    }

    var body: some View {
        MessageWebView(
            html: resolvedHTML ?? html,
            width: width,
            darkAdapted: isDarkAdapted,
            height: $height,
            isReady: $isReady
        )
            .opacity(isReady ? 1 : 0)
            .frame(height: height)
            .background {
                if isSlow && !isReady {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                }
            }
            .clipShape(.rect(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                if isReady {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .strokeBorder(Palette.separator.opacity(0.6), lineWidth: Metrics.hairline)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isReady && colorScheme == .dark {
                    Button {
                        overrideDarkMode = !isDarkAdapted
                    } label: {
                        Image(systemName: isDarkAdapted ? "sun.max.fill" : "moon.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isDarkAdapted ? Palette.label : Color.black.opacity(0.65))
                            .padding(6)
                            .background(.ultraThinMaterial, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .padding(Spacing.xs)
                    .help(isDarkAdapted ? "View with light background" : "Adapt for Dark Mode")
                    .accessibilityLabel(isDarkAdapted ? "View with light background" : "Adapt for Dark Mode")
                }
            }
            .animation(Motion.scene, value: isReady)
            .animation(Motion.scene, value: isSlow)
            .task {
                try? await Task.sleep(for: .milliseconds(400))
                isSlow = true
            }
            .task(id: html) {
                guard !inlineImages.isEmpty, let store else {
                    resolvedHTML = nil
                    return
                }
                var updated = html
                var changed = false
                for image in inlineImages {
                    guard updated.localizedCaseInsensitiveContains("cid:\(image.contentID)") else { continue }
                    let proxy = Attachment(
                        id: "cid-\(image.messageID)-\(image.contentID)",
                        filename: image.contentID,
                        messageID: image.messageID,
                        attachmentID: image.attachmentID,
                        mimeType: image.mimeType
                    )
                    if let data = try? await store.attachmentData(for: proxy) {
                        let dataURI = "data:\(image.mimeType);base64,\(data.base64EncodedString())"
                        updated = updated.replacing("cid:\(image.contentID)", with: dataURI)
                        changed = true
                    }
                }
                if changed {
                    resolvedHTML = updated
                }
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
