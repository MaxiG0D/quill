import SwiftUI
import WebKit

/// The web view behind `HTMLMessageView`.
///
/// The message's own scripts never run, nothing it stores outlives the view, and a tapped
/// link opens in the browser instead of inside the message. The page does not scroll by
/// itself: the view reports the page's height so the thread can scroll as one.
@MainActor
struct MessageWebView {
    let html: String
    /// The width on offer. A change means the page must be fitted again.
    let width: Double
    /// Adapts a light HTML email for Dark Mode reading when enabled.
    var darkAdapted = false
    @Binding var height: Double
    /// Set once the page can show without its layout moving, or has taken long enough that it should show anyway.
    @Binding var isReady: Bool

    @Environment(\.openURL) private var openURL
    @Environment(Router.self) private var router: Router?

    /// One store for every message, apart from the browser's. It keeps pictures on the
    /// device so a message opens without fetching them again, and it refuses cookies, so a
    /// sender cannot use it to follow the reader from one message to the next.
    private static let store = WKWebsiteDataStore(forIdentifier: UUID(uuid: (0x51, 0x75, 0x69, 0x6C, 0x6C, 0x4D, 0x41, 0x49, 0x4C, 0x50, 0x41, 0x47, 0x45, 0x53, 0x30, 0x31)))
    /// A view made ahead of time, with its web process already running.
    private static var spare: WKWebView?

    private static var configuration: WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = store
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        return configuration
    }

    /// Starts the web engine ahead of the first designed message, which would otherwise wait for it.
    static func warmUp() async {
        guard spare == nil else { return }
        await store.httpCookieStore.setCookiePolicy(.disallow)
        spare = makeSpare()
    }

    /// A view that shares the messages' store but is never shown.
    static func makeHiddenView() -> WKWebView {
        WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 800), configuration: configuration)
    }

    private static func makeSpare() -> WKWebView {
        let view = MessageWKWebView(frame: .zero, configuration: configuration)
        view.loadHTMLString(HTMLDocument.page(for: ""), baseURL: nil)
        return view
    }

    /// Hands over the view made ahead of time, and starts on the next one.
    private static func takeView() -> WKWebView {
        let view = spare ?? MessageWKWebView(frame: .zero, configuration: configuration)
        spare = nil
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            if spare == nil {
                spare = makeSpare()
            }
        }
        return view
    }

    /// Removes every picture kept from the account's mail.
    static func forget() async {
        spare = nil
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func makeView(_ coordinator: Coordinator) -> WKWebView {
        let view = Self.takeView()
        view.navigationDelegate = coordinator
        // The page is measured against the view's own width, which can arrive after the width on offer.
        (view as? MessageWKWebView)?.resized = { [weak coordinator] view in
            coordinator?.fitIfCommitted(view)
        }
        #if canImport(UIKit)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        #else
        view.setValue(false, forKey: "drawsBackground")
        #endif
        return view
    }

    private func update(_ view: WKWebView, _ coordinator: Coordinator) {
        let router = router
        let openURL = openURL
        coordinator.open = { url in
            if url.scheme?.lowercased() == "mailto", let router, let draft = Self.draft(from: url) {
                router.draft = draft
            } else {
                openURL(url)
            }
        }
        coordinator.report = { newHeight in
            if abs(height - newHeight) > 0.5 {
                height = newHeight
            }
        }
        coordinator.reveal = {
            if !isReady {
                isReady = true
            }
        }
        if coordinator.html != html || coordinator.darkAdapted != darkAdapted {
            coordinator.html = html
            coordinator.darkAdapted = darkAdapted
            coordinator.width = width
            coordinator.hasCommitted = false
            if isReady {
                isReady = false
            }
            view.loadHTMLString(HTMLDocument.page(for: html, darkAdapted: darkAdapted), baseURL: nil)
        } else if coordinator.width != width {
            coordinator.width = width
            coordinator.fitIfCommitted(view)
        }
    }

    /// Parses a `mailto:` link into a Quill draft so tapping an address composes inside the app.
    static func draft(from url: URL) -> Draft? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let rawTo = components.path.removingPercentEncoding ?? components.path
        let addresses = rawTo
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("@") }
        let to = addresses.map { Contact(name: "", email: $0) }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
        let cc = (value("cc") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("@") }
            .map { Contact(name: "", email: $0) }
        let bcc = (value("bcc") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("@") }
            .map { Contact(name: "", email: $0) }
        return Draft(to: to, cc: cc, bcc: bcc, subject: value("subject") ?? "", body: value("body") ?? "")
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var html: String?
        var darkAdapted = false
        var width = 0.0
        var hasCommitted = false
        var open: (URL) -> Void = { _ in }
        var report: (Double) -> Void = { _ in }
        var reveal: () -> Void = {}
        private var settling: Task<Void, Never>?

        func fitIfCommitted(_ view: WKWebView) {
            guard hasCommitted else { return }
            fit(view)
        }

        /// Measures the page. It is shown once nothing still loading can move it, or when asked to regardless.
        func fit(_ view: WKWebView, revealing: Bool = false) {
            view.evaluateJavaScript(HTMLDocument.fitScript(width: view.bounds.width)) { [weak self] result, _ in
                let values = result as? [NSNumber] ?? []
                if let height = values.first?.doubleValue, height > 0 {
                    self?.report(height)
                }
                if revealing || values.last?.boolValue == true {
                    self?.reveal()
                }
            }
        }

        /// Text is laid out the moment the page arrives, so a message whose pictures state
        /// their sizes shows at once and the pictures fill in. One whose pictures would push
        /// the text around stays hidden a little longer, so it does not appear in steps.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            hasCommitted = true
            settling?.cancel()
            settling = Task { [weak self, weak webView] in
                for (pause, reveals) in [(20, false), (80, false), (150, false), (250, false), (300, true), (700, false), (1500, false), (3000, false)] {
                    try? await Task.sleep(for: .milliseconds(pause))
                    guard !Task.isCancelled, let self, let webView else { return }
                    self.fit(webView, revealing: reveals)
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasCommitted = true
            settling?.cancel()
            fit(webView, revealing: true)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url, ["http", "https", "mailto", "tel"].contains(url.scheme?.lowercased() ?? "") {
                    open(url)
                }
                return .cancel
            }
            // Only allow loading the message's own local HTML (about:blank); block redirects and external frames.
            let scheme = navigationAction.request.url?.scheme?.lowercased()
            if scheme == nil || scheme == "about" || scheme == "data" {
                return .allow
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

/// Tells the page when its width changes, so it can be fitted again.
private final class MessageWKWebView: WKWebView {
    var resized: (@MainActor (WKWebView) -> Void)?
    private var fittedWidth = 0.0

    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(bounds.width - fittedWidth) > 0.5 {
            fittedWidth = bounds.width
            resized?(self)
        }
    }
}
#else
extension MessageWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        update(view, context.coordinator)
    }
}

/// Passes scrolling on to the thread, since the page itself never scrolls, and tells the
/// page when its width changes, so it can be fitted again.
private final class MessageWKWebView: WKWebView {
    var resized: (@MainActor (WKWebView) -> Void)?

    override func setFrameSize(_ newSize: NSSize) {
        let changed = abs(newSize.width - frame.width) > 0.5
        super.setFrameSize(newSize)
        if changed {
            resized?(self)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}
#endif
