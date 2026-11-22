import Foundation
import Observation

/// User preferences kept in `UserDefaults` across launches.
@MainActor
@Observable
final class MailPreferences {
    static let shared = MailPreferences()

    var undoSendEnabled: Bool {
        didSet { defaults.set(undoSendEnabled, forKey: Keys.undoSend) }
    }
    var darkModeHTML: Bool {
        didSet { defaults.set(darkModeHTML, forKey: Keys.darkModeHTML) }
    }
    var signatureEnabled: Bool {
        didSet { defaults.set(signatureEnabled, forKey: Keys.signatureEnabled) }
    }
    var signature: String {
        didSet { defaults.set(signature, forKey: Keys.signature) }
    }
    var leadingSwipe: SwipeAction {
        didSet { defaults.set(leadingSwipe.rawValue, forKey: Keys.leadingSwipe) }
    }
    var leadingSecondarySwipe: SwipeAction {
        didSet { defaults.set(leadingSecondarySwipe.rawValue, forKey: Keys.leadingSecondarySwipe) }
    }
    var trailingSwipe: SwipeAction {
        didSet { defaults.set(trailingSwipe.rawValue, forKey: Keys.trailingSwipe) }
    }
    var trailingSecondarySwipe: SwipeAction {
        didSet { defaults.set(trailingSecondarySwipe.rawValue, forKey: Keys.trailingSecondarySwipe) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let undoSend = "prefs.undoSendEnabled"
        static let darkModeHTML = "prefs.darkModeHTML"
        static let signatureEnabled = "prefs.signatureEnabled"
        static let signature = "prefs.signature"
        static let leadingSwipe = "prefs.leadingSwipe"
        static let leadingSecondarySwipe = "prefs.leadingSecondarySwipe"
        static let trailingSwipe = "prefs.trailingSwipe"
        static let trailingSecondarySwipe = "prefs.trailingSecondarySwipe"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        undoSendEnabled = defaults.object(forKey: Keys.undoSend) as? Bool ?? true
        darkModeHTML = defaults.object(forKey: Keys.darkModeHTML) as? Bool ?? false
        signatureEnabled = defaults.object(forKey: Keys.signatureEnabled) as? Bool ?? false
        signature = defaults.string(forKey: Keys.signature) ?? ""
        leadingSwipe = defaults.string(forKey: Keys.leadingSwipe).flatMap(SwipeAction.init) ?? .unread
        leadingSecondarySwipe = defaults.string(forKey: Keys.leadingSecondarySwipe).flatMap(SwipeAction.init) ?? .pin
        trailingSwipe = defaults.string(forKey: Keys.trailingSwipe).flatMap(SwipeAction.init) ?? .archive
        trailingSecondarySwipe = defaults.string(forKey: Keys.trailingSecondarySwipe).flatMap(SwipeAction.init) ?? .delete
    }

    /// Signature text to append to a new draft, or nil when disabled or empty.
    var activeSignature: String? {
        guard signatureEnabled else { return nil }
        let trimmed = signature.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
