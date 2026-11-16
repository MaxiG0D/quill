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
        </style>
        </head>
        <body><div id="quill-message">\(html)</div></body>
        </html>
        """
    }

    /// Shrinks a page wider than its view until it fits, then reports its height in points.
    static let fitScript = """
        (function () {
            var message = document.getElementById("quill-message");
            message.style.zoom = 1;
            var available = document.documentElement.clientWidth;
            var needed = message.scrollWidth;
            if (needed > available + 1) { message.style.zoom = available / needed; }
            return Math.ceil(message.getBoundingClientRect().height);
        })()
        """
}
