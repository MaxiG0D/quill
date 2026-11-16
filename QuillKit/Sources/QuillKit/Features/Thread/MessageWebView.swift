import SwiftUI
import WebKit

/// The web view behind `HTMLMessageView`.
///
/// The message's own scripts never run, nothing it stores outlives the view, and a tapped
/// link opens in the browser instead of inside the message. The page does not scroll by
/// itself: the view reports the page's height so the thread can scroll as one.
struct MessageWebView {
    let html: String
    /// The width on offer. A change means the page must be fitted again.
    let width: Double
    @Binding var height: Double

    @Environment(\.openURL) private var openURL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func makeView(_ coordinator: Coordinator) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = MessageWKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = coordinator
        #if canImport(UIKit)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        #endif
        return view
    }

    private func update(_ view: WKWebView, _ coordinator: Coordinator) {
        coordinator.open = { url in openURL(url) }
        coordinator.report = { newHeight in
            if abs(height - newHeight) > 0.5 {
                height = newHeight
            }
        }
        if coordinator.html != html {
            coordinator.html = html
            coordinator.width = width
            view.loadHTMLString(HTMLDocument.page(for: html), baseURL: nil)
        } else if coordinator.width != width {
            coordinator.width = width
            coordinator.fit(view)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var html: String?
        var width = 0.0
        var open: (URL) -> Void = { _ in }
        var report: (Double) -> Void = { _ in }

        func fit(_ view: WKWebView) {
            view.evaluateJavaScript(HTMLDocument.fitScript) { [weak self] result, _ in
                guard let number = result as? NSNumber, number.doubleValue > 0 else { return }
                self?.report(number.doubleValue)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            fit(webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated else { return .allow }
            if let url = navigationAction.request.url, ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                open(url)
            }
            return .cancel
        }
    }
}

#if canImport(UIKit)
extension MessageWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        update(view, context.coordinator)
    }
}

private final class MessageWKWebView: WKWebView {}
#else
extension MessageWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        update(view, context.coordinator)
    }
}

/// Passes scrolling on to the thread, since the page itself never scrolls.
private final class MessageWKWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}
#endif
