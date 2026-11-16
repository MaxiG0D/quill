import Foundation

extension Data {
    /// Decodes the URL-safe base64 that OAuth and Gmail use, with or without padding.
    init?(base64URLEncoded string: String) {
        var text = string.replacing("-", with: "+").replacing("_", with: "/")
        text.removeAll(where: \.isWhitespace)
        let remainder = text.count % 4
        if remainder > 0 {
            text += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: text)
    }

    /// URL-safe base64 without padding.
    var base64URLEncoded: String {
        base64EncodedString()
            .replacing("+", with: "-")
            .replacing("/", with: "_")
            .replacing("=", with: "")
    }
}
