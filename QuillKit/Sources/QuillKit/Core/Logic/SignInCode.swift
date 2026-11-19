import Foundation

/// A sign-in or verification code found in a message. The relay follows the same rules
/// (`Relay/src/code.js`), and both are checked against the same examples.
struct SignInCode: Hashable, Sendable {
    /// The code as typed: digits only.
    let digits: String

    /// The code in groups that are easy to read: 482913 becomes "482 913".
    var display: String {
        switch digits.count {
        case 6: "\(digits.prefix(3)) \(digits.suffix(3))"
        case 8: "\(digits.prefix(4)) \(digits.suffix(4))"
        default: digits
        }
    }

    private static let keyword = regex(
        #"\b(?:code|passcode|pass code|otp|one[- ]time|verification|v[ée]rif\w*|verify|s[ée]curit[ée]|security|confirmation|log[- ]?in|sign[- ]?in|connexion|2fa|two[- ]factor|authenticat\w*|authentification|pin)\b"#
    )
    private static let candidate = regex(#"(?<![\w$#£€.,/-])(?<!\d[ -])(\d{3}[ -]\d{3}|\d{4}[ -]\d{4}|\d{4,8})(?![\w%]|[.,]\d|[ -]\d{3,4}\b)"#)
    /// Card, receipt and payment wording: a number beside it is not a sign-in code.
    private static let receipt = regex(
        #"\b(?:receipts?|cards?|transactions?|orders?|invoices?|payments?|purchases?|factures?|re[cç]us?|achats?|cartes?|commandes?|paiements?)\b"#
    )
    private static let notACode = regex(
        #"\b(?:order|invoice|tracking|ticket|case|account|reference|ref|phone|call|amount|total|receipt|zip)\s*(?:no\.?|number|#)?\W*$"#
    )

    /// The first sign-in code in `text`, or nil when there is none.
    static func find(in text: String) -> SignInCode? {
        let whole = NSRange(text.startIndex..., in: text)
        for match in candidate.matches(in: text, range: whole) {
            guard let range = Range(match.range(at: 1), in: text) else { continue }
            let digits = text[range].filter(\.isNumber)
            if digits.count == 4, digits.hasPrefix("19") || digits.hasPrefix("20") { continue }

            let before = String(text[..<range.lowerBound].suffix(60))
            let after = String(text[range.upperBound...].prefix(25))
            if matches(notACode, String(before.suffix(24))) { continue }
            if matches(receipt, String(before.suffix(40))) || matches(receipt, String(after.prefix(20))) { continue }
            if matches(keyword, before) || matches(keyword, after) {
                return SignInCode(digits: String(digits))
            }
        }
        return nil
    }

    private static func matches(_ expression: NSRegularExpression, _ text: String) -> Bool {
        expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // The patterns are constants, checked by the tests.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
