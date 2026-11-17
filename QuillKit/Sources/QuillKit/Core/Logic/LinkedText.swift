import Foundation

/// Plain message text with its web addresses, email addresses and phone numbers made tappable.
enum LinkedText {
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
    )

    static func make(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        guard let detector else { return result }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = link(for: match),
                  let textRange = Range(match.range, in: text),
                  let target = Range(textRange, in: result) else { continue }
            result[target].link = url
        }
        return result
    }

    private static func link(for match: NSTextCheckingResult) -> URL? {
        if let phone = match.phoneNumber {
            let digits = phone.filter { $0.isNumber || $0 == "+" }
            return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
        }
        guard let url = match.url, ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }
}
