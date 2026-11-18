import Foundation

/// Whether a sign-in code may appear as a Live Activity on this device. On by default.
/// Off, the device keeps its Live Activity token from the push relay, so the relay sends
/// the ordinary code alert instead.
public enum LiveActivitySetting {
    public static let key = "liveActivity"

    public static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Run when the setting is turned off, so the app can end any activity that is up.
    @MainActor public static var onTurnedOff: (@MainActor () async -> Void)?
}
