/// Wraps a message's HTML in a page that fits the reading column.
enum HTMLDocument {
    /// Mail is designed for a white page, so the page stays light in Dark Mode, as it does in Gmail.
    static func page(for html: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light only">
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
        </style>
        </head>
        <body><div id="quill-message">\(html)</div></body>
        </html>
        """
    }

    /// Fits a page to its view, then reports `[height, isSettled]`: its height in points, and
    /// 1 when no picture still to arrive can change that height, because each one has loaded
    /// or states its size.
    ///
    /// A page laid out wider than its view is first let to flow at that width, as Gmail does,
    /// so a fixed-width design wraps at a readable size. Only what still overflows is shrunk.
    static let fitScript = """
        (function () {
            var message = document.getElementById("quill-message");
            message.style.zoom = 1;
            var marks = ["data-quill-wide", "data-quill-narrow-left", "data-quill-narrow-right"];
            Array.prototype.forEach.call(message.querySelectorAll("[" + marks.join("],[") + "]"), function (element) {
                marks.forEach(function (mark) { element.removeAttribute(mark); });
            });
            var available = document.documentElement.clientWidth;
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
            var settled = Array.prototype.every.call(document.images, function (image) {
                return image.complete || (image.getAttribute("width") && image.getAttribute("height"));
            });
            return [Math.ceil(message.getBoundingClientRect().height), settled ? 1 : 0];
        })()
        """
}
