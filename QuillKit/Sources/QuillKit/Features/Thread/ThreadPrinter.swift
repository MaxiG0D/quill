import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
import WebKit
#endif

/// Prints a conversation or exports it to PDF via the system print panel.
@MainActor
final class ThreadPrinter: NSObject {
    static let shared = ThreadPrinter()

    #if os(macOS)
    private var activeWebView: WKWebView?
    #endif

    func printThread(_ thread: MailThread, timestamp: MailTimestamp) {
        let html = printableHTML(for: thread, timestamp: timestamp)
        #if os(iOS)
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = thread.subject
        controller.printInfo = info
        controller.printFormatter = UIMarkupTextPrintFormatter(markupText: html)
        controller.present(animated: true)
        #else
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792), configuration: configuration)
        webView.navigationDelegate = self
        activeWebView = webView
        webView.loadHTMLString(html, baseURL: nil)
        #endif
    }

    /// Renders a clean printable HTML document for all messages in `thread`.
    func printableHTML(for thread: MailThread, timestamp: MailTimestamp) -> String {
        func escape(_ text: String) -> String {
            text
                .replacing("&", with: "&amp;")
                .replacing("<", with: "&lt;")
                .replacing(">", with: "&gt;")
        }
        let sections = thread.messages.map { message -> String in
            let from = escape(message.sender.name.isEmpty ? message.sender.email : "\(message.sender.displayName) <\(message.sender.email)>")
            let to = message.to.isEmpty ? "" : "<div class=\"meta\"><strong>To:</strong> \(escape(message.to.map(\.displayName).joined(separator: ", ")))</div>"
            let cc = message.cc.isEmpty ? "" : "<div class=\"meta\"><strong>Cc:</strong> \(escape(message.cc.map(\.displayName).joined(separator: ", ")))</div>"
            let date = escape(timestamp.long(message.date))
            let body: String
            if let html = message.html {
                body = html
            } else {
                body = "<div class=\"plain\">\(escape(message.body).replacing("\n", with: "<br>"))</div>"
            }
            return """
            <section class="message">
              <div class="header">
                <div class="from">\(from)</div>
                <div class="date">\(date)</div>
              </div>
              \(to)\(cc)
              <div class="body">\(body)</div>
            </section>
            """
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, Helvetica, sans-serif; color: #151918; margin: 28px; font-size: 13px; line-height: 1.5; }
          h1 { font-family: Georgia, serif; font-size: 22px; margin: 0 0 18px 0; padding-bottom: 10px; border-bottom: 1px solid #d8dcd6; }
          .message { margin-bottom: 22px; padding-bottom: 18px; border-bottom: 1px solid #e5e8e3; page-break-inside: avoid; }
          .header { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 4px; }
          .from { font-weight: 600; font-size: 14px; }
          .date, .meta { color: #5d6561; font-size: 12px; }
          .body { margin-top: 10px; }
          .plain { white-space: normal; }
          img { max-width: 100%; height: auto; }
        </style>
        </head>
        <body>
          <h1>\(escape(thread.subject))</h1>
          \(sections)
        </body>
        </html>
        """
    }
}

#if os(macOS)
extension ThreadPrinter: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        if let window = NSApp.keyWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }
}
#endif
