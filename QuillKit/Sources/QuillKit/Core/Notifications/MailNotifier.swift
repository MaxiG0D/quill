import Foundation
import Observation

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Tells the person about new mail: a notification for each message that arrives while
/// Quill is out of sight, and the unread count on the app's icon.
///
/// Once the push relay has this device, the relay sends the notifications and this class
/// only keeps the badge and the delivered notifications in step with the mailbox.
@MainActor
@Observable
final class MailNotifier {
    private(set) var permission = NotificationPermission.undecided
    /// The person's own choice in Settings. Notifications also need the system's permission.
    private(set) var isEnabled: Bool
    /// True while the push relay is sending this device its notifications.
    private(set) var isPushed: Bool
    /// Told when the person turns notifications on or off, so the relay can follow.
    var onSwitch: (@MainActor (Bool) async -> Void)?

    private let poster: any NotificationPosting
    private let defaults: UserDefaults
    private let isAppActive: @MainActor () -> Bool
    private let clock: @Sendable () -> Date

    /// The most notifications one refresh shows. After a long time away, the newest are enough.
    private static let burstLimit = 6
    private static let enabledKey = "notifiesNewMail"
    private static let ledgerKey = "newMailLedger"
    private static let pushedKey = "relayNotifiesNewMail"

    init(
        poster: any NotificationPosting = SystemNotifications(),
        defaults: UserDefaults = .standard,
        isAppActive: @escaping @MainActor () -> Bool = MailNotifier.appIsActive,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.poster = poster
        self.defaults = defaults
        self.isAppActive = isAppActive
        self.clock = clock
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        isPushed = defaults.bool(forKey: Self.pushedKey)
    }

    var isOn: Bool {
        isEnabled && permission == .allowed
    }

    /// Asks for the system's permission the first time, while Quill is on screen.
    func prepare() async {
        await readPermission()
        if isEnabled, permission == .undecided, isAppActive() {
            permission = await poster.requestPermission()
        }
    }

    /// Picks up a change made in the system's settings.
    func readPermission() async {
        permission = await poster.permission()
    }

    /// Turns notifications on or off. Returns false when only the system's settings can turn them on.
    func setOn(_ isOn: Bool) async -> Bool {
        isEnabled = isOn
        defaults.set(isOn, forKey: Self.enabledKey)
        await onSwitch?(isOn)
        guard isOn else {
            await clear()
            return true
        }
        await readPermission()
        if permission == .undecided {
            permission = await poster.requestPermission()
        }
        return permission == .allowed
    }

    /// Takes in a freshly fetched mailbox: notifies about what is new in it, unless the
    /// person is already looking at Quill, and brings the badge up to date.
    func announce(_ threads: [MailThread], account: Contact) async {
        let now = clock()
        var ledger = self.ledger ?? NewMailLedger(since: now)
        let mail = ledger.collect(from: threads, account: account, now: now)
        self.ledger = ledger

        await readPermission()
        await reflect(threads)
        guard isOn, !isPushed, !mail.isEmpty, !isAppActive() else { return }
        await poster.post(Array(mail.suffix(Self.burstLimit)))
    }

    /// Matches the badge to the unread Inbox, and removes notifications for mail that has been dealt with.
    func reflect(_ threads: [MailThread]) async {
        guard isOn else { return }
        let now = clock()
        let waiting = threads.filter { $0.isUnread && $0.belongs(to: .mailbox(.inbox), at: now) }
        await poster.setBadge(waiting.count)
        await poster.withdraw(keeping: Set(waiting.map(\.id)))
    }

    /// Records whether the push relay has taken over sending this device's notifications.
    func setPushed(_ isPushed: Bool) {
        self.isPushed = isPushed
        defaults.set(isPushed, forKey: Self.pushedKey)
    }

    /// Forgets the account on sign-out.
    func reset() async {
        ledger = nil
        setPushed(false)
        await clear()
    }

    private func clear() async {
        await poster.setBadge(0)
        await poster.withdraw(keeping: [])
    }

    private var ledger: NewMailLedger? {
        get {
            defaults.data(forKey: Self.ledgerKey).flatMap { try? JSONDecoder().decode(NewMailLedger.self, from: $0) }
        }
        set {
            defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.ledgerKey)
        }
    }

    /// True while Quill is the app in front.
    static func appIsActive() -> Bool {
        #if os(iOS)
        UIApplication.shared.applicationState == .active
        #else
        NSApplication.shared.isActive
        #endif
    }
}
