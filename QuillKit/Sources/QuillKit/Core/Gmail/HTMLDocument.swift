/// Wraps a message's HTML in a page that fits the reading column.
enum HTMLDocument {
    /// Mail is designed for a white page, so the page stays light in Dark Mode, as it does in Gmail.
    ///
    /// A viewport the sender set is dropped: one built for a desktop width would have the
    /// whole page drawn small, out of reach of the fitting below.
    static func page(for html: String, darkAdapted: Bool = false) -> String {
        var html = html.replacingOccurrences(
            of: #"<meta\b[^>]*\bname\s*=\s*["']?viewport\b[^>]*>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // Drop meta refreshes so a sender cannot redirect the message view to another page.
        html = html.replacingOccurrences(
            of: #"<meta\b[^>]*\bhttp-equiv\s*=\s*["']?refresh\b[^>]*>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        html = securePictures(in: html)
        let darkStyle = darkAdapted
            ? """
              html { background: #141a19; filter: invert(0.92) hue-rotate(180deg); }
              img, video, picture, svg { filter: invert(1) hue-rotate(180deg); }
              """
            : ""
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
        <meta name="color-scheme" content="light only">
        <meta name="referrer" content="no-referrer">
        <style>
        html { background: #fff; color: #1f1f1f; -webkit-text-size-adjust: 100%; }
        body { margin: 0; padding: 0; font: -apple-system-body; overflow-wrap: break-word; }
        img { max-width: 100%; height: auto; }
        [data-quill-wide] { min-width: 0 !important; max-width: 100% !important; box-sizing: border-box !important; }
        table[data-quill-wide] { width: 100% !important; }
        [data-quill-wide]:not(table) { width: auto !important; }
        img[data-quill-wide] { height: auto !important; }
        [data-quill-narrow-left] { padding-left: 24px !important; }
        [data-quill-narrow-right] { padding-right: 24px !important; }
        \(darkStyle)
        </style>
        </head>
        <body><div id="quill-message">\(html)</div></body>
        </html>
        """
    }

    /// Pictures a page cannot fetch as written: plain `http` ones, which the system refuses, and
    /// ones given without a scheme, which have nothing to be relative to inside a message.
    static func securePictures(in html: String) -> String {
        var html = html
        for (pattern, template) in [
            (#"(<img\b[^>]*?\bsrc\s*=\s*["'])http://"#, "$1https://"),
            (#"(<img\b[^>]*?\bsrc\s*=\s*["'])//"#, "$1https://"),
            (#"(<(?:td|table|div|body|v:fill|v:background)\b[^>]*?\b(?:background|src)\s*=\s*["'])http://"#, "$1https://"),
            (#"(url\(\s*["']?)http://"#, "$1https://"),
            (#"(url\(\s*["']?)//"#, "$1https://"),
        ] {
            html = html.replacingOccurrences(of: pattern, with: template, options: [.regularExpression, .caseInsensitive])
        }
        return html
    }

    /// Fits a page to its view, then reports `[height, isSettled]`: its height in points, and
    /// 1 when no picture still to arrive can change that height, because each one has loaded
    /// or states its size.
    ///
    /// A page laid out wider than its view is first let to flow at that width, as Gmail does,
    /// so a fixed-width design wraps at a readable size. Only what still overflows is shrunk.
    static func fitScript(width: Double) -> String {
        """
        (function () {
            var message = document.getElementById("quill-message");
            message.style.zoom = 1;
            var marks = ["data-quill-wide", "data-quill-narrow-left", "data-quill-narrow-right"];
            Array.prototype.forEach.call(message.querySelectorAll("[" + marks.join("],[") + "]"), function (element) {
                marks.forEach(function (mark) { element.removeAttribute(mark); });
            });
            var available = \(width) || document.documentElement.clientWidth;
            // Held to the view's width even if the engine lays the page out wider.
            message.style.maxWidth = available + "px";
            if (message.scrollWidth > available + 1) {
                var elements = Array.prototype.slice.call(message.querySelectorAll("*"));
                elements.forEach(function (element) {
                    if (element.getBoundingClientRect().width > available + 1) {
                        element.setAttribute("data-quill-wide", "");
                    }
                });
                // Margins drawn for a wide screen would leave a narrow column of text on a small one.
                elements.forEach(function (element) {
                    var style = getComputedStyle(element);
                    if (parseFloat(style.paddingLeft) > 24) { element.setAttribute("data-quill-narrow-left", ""); }
                    if (parseFloat(style.paddingRight) > 24) { element.setAttribute("data-quill-narrow-right", ""); }
                });
            }
            var needed = message.scrollWidth;
            if (needed > available + 1) { message.style.zoom = available / needed; }
            // A picture that failed would show the engine's broken-image box; show nothing instead.
            Array.prototype.forEach.call(document.images, function (image) {
                if (image.complete && image.naturalWidth === 0 && image.getAttribute("src")) {
                    image.style.visibility = "hidden";
                }
            });
            var settled = Array.prototype.every.call(document.images, function (image) {
                return image.complete || (image.getAttribute("width") && image.getAttribute("height"));
            });
            var height = Math.max(message.getBoundingClientRect().height, document.body.scrollHeight);
            return [Math.ceil(height), settled ? 1 : 0];
        })()
        """
    }
}
