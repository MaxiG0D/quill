import Foundation
import Testing
@testable import QuillKit

@MainActor
struct NotificationTests {
    private static let me = GmailFixture.me
    private static let priya = Contact(name: "Priya Raman", email: "priya@example.com")
    private nonisolated static let start = Date(timeIntervalSince1970: 1_000_000)

    private static func message(_ id: String, from sender: Contact = priya, after seconds: TimeInterval, body: String = "Hello") -> Message {
        Message(id: id, sender: sender, date: start.addingTimeInterval(seconds), body: body)
    }

    private static func thread(_ id: String, _ messages: [Message], folder: Mailbox = .inbox, isUnread: Bool = true) -> MailThread {
        MailThread(id: id, subject: "Subject \(id)", messages: messages, folder: folder, isUnread: isUnread)
    }

    private static func defaults() throws -> UserDefaults {
        let name = "quill.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func notifier(_ log: NotificationLog, defaults: UserDefaults, isActive: Bool = false) -> MailNotifier {
        MailNotifier(poster: log, defaults: defaults, isAppActive: { isActive }, clock: { start.addingTimeInterval(3600) })
    }

    // MARK: Ledger

    @Test func announcesEachNewMessageOnce() {
        var ledger = NewMailLedger(since: Self.start)
        let threads = [Self.thread("t1", [Self.message("m1", after: 10, body: "Hi Max,\nLunch on Friday?")])]

        let first = ledger.collect(from: threads, account: Self.me, now: Self.start)
        #expect(first == [NewMail(threadID: "t1", messageID: "m1", sender: "Priya Raman", address: "priya@example.com", subject: "Subject t1", preview: "Lunch on Friday?")])
        #expect(ledger.collect(from: threads, account: Self.me, now: Self.start).isEmpty)
    }

    @Test func staysQuietAboutOldReadFiledAndOwnMail() {
        var ledger = NewMailLedger(since: Self.start)
        let threads = [
            Self.thread("old", [Self.message("m1", after: -10)]),
            Self.thread("read", [Self.message("m2", after: 10)], isUnread: false),
            Self.thread("archived", [Self.message("m3", after: 10)], folder: .archive),
            Self.thread("mine", [Self.message("m4", from: Self.me, after: 10)]),
            Self.thread("snoozed", [Self.message("m5", after: 10)]).snoozed(until: Self.start.addingTimeInterval(7200)),
        ]
        #expect(ledger.collect(from: threads, account: Self.me, now: Self.start).isEmpty)
    }

    @Test func mailMarkedUnreadLaterIsNotNew() {
        var ledger = NewMailLedger(since: Self.start)
        let message = Self.message("m1", after: 10)
        _ = ledger.collect(from: [Self.thread("t1", [message], isUnread: false)], account: Self.me, now: Self.start)
        #expect(ledger.collect(from: [Self.thread("t1", [message])], account: Self.me, now: Self.start).isEmpty)
    }

    @Test func aBusyThreadAnnouncesItsLatestMessageFromSomeoneElse() {
        var ledger = NewMailLedger(since: Self.start)
        let messages = [
            Self.message("m1", after: 10),
            Self.message("m2", after: 20),
            Self.message("m3", from: Self.me, after: 30),
        ]
        let mail = ledger.collect(from: [Self.thread("t1", messages)], account: Self.me, now: Self.start)
        #expect(mail.map(\.messageID) == ["m2"])
    }

    @Test func forgetsTheOldestMessagesPastItsLimit() {
        var ledger = NewMailLedger(since: Self.start)
        let messages = (0..<NewMailLedger.limit + 5).map { Self.message("m\($0)", after: Double($0 + 1)) }
        _ = ledger.collect(from: [Self.thread("t1", messages)], account: Self.me, now: Self.start)
        #expect(ledger.seen.count == NewMailLedger.limit)
        #expect(ledger.seen.first == "m5")
    }

    // MARK: Notifier

    @Test func theFirstRefreshAnnouncesNothingAndLaterMailIsPosted() async throws {
        let log = NotificationLog()
        let notifier = Self.notifier(log, defaults: try Self.defaults())
        let known = Self.thread("t1", [Self.message("m1", after: 0)])
        await notifier.announce([known], account: Self.me)
        #expect(await log.posted.isEmpty)
        #expect(await log.badge == 1)

        let arrived = Self.thread("t2", [Self.message("m2", after: 7200)])
        await notifier.announce([known, arrived], account: Self.me)
        #expect(await log.posted.map(\.messageID) == ["m2"])
        #expect(await log.badge == 2)
        #expect(await log.kept == ["t1", "t2"])
    }

    @Test func staysQuietWhileQuillIsInFront() async throws {
        let log = NotificationLog()
        let defaults = try Self.defaults()
        await Self.notifier(log, defaults: defaults).announce([], account: Self.me)

        let arrived = Self.thread("t2", [Self.message("m2", after: 7200)])
        await Self.notifier(log, defaults: defaults, isActive: true).announce([arrived], account: Self.me)
        // Seen in the app, so it is not announced once Quill leaves the screen either.
        await Self.notifier(log, defaults: defaults).announce([arrived], account: Self.me)
        #expect(await log.posted.isEmpty)
        #expect(await log.badge == 1)
    }

    @Test func turningOffClearsTheBadgeAndStopsPosting() async throws {
        let log = NotificationLog()
        let notifier = Self.notifier(log, defaults: try Self.defaults())
        await notifier.announce([], account: Self.me)
        #expect(await notifier.setOn(false))
        #expect(await log.badge == 0)
        #expect(await log.kept == [])

        await notifier.announce([Self.thread("t2", [Self.message("m2", after: 7200)])], account: Self.me)
        #expect(await log.posted.isEmpty)
        #expect(!notifier.isOn)
    }

    @Test func asksOnceAndSendsABlockedSwitchToTheSystem() async throws {
        let asked = NotificationLog(.undecided, reply: .allowed)
        let first = Self.notifier(asked, defaults: try Self.defaults(), isActive: true)
        await first.prepare()
        await first.prepare()
        #expect(await asked.requests == 1)
        #expect(first.isOn)

        let blocked = Self.notifier(NotificationLog(.denied), defaults: try Self.defaults())
        #expect(await !blocked.setOn(true))
        #expect(!blocked.isOn)
    }

    @Test func leavesAnnouncingToThePushRelayOnceItHasTheDevice() async throws {
        let log = NotificationLog()
        let defaults = try Self.defaults()
        let notifier = Self.notifier(log, defaults: defaults)
        await notifier.announce([], account: Self.me)
        notifier.setPushed(true)

        let arrived = Self.thread("t2", [Self.message("m2", after: 7200)])
        await notifier.announce([arrived], account: Self.me)
        #expect(await log.posted.isEmpty)
        #expect(await log.badge == 1)
        #expect(Self.notifier(log, defaults: defaults).isPushed)

        await notifier.reset()
        #expect(!notifier.isPushed)
    }

    @Test func tellsTheSessionWhenThePersonFlipsTheSwitch() async throws {
        let notifier = Self.notifier(NotificationLog(), defaults: try Self.defaults())
        var heard: [Bool] = []
        notifier.onSwitch = { heard.append($0) }
        _ = await notifier.setOn(false)
        _ = await notifier.setOn(true)
        #expect(heard == [false, true])
    }

    @Test func signingOutForgetsWhatWasSeen() async throws {
        let log = NotificationLog()
        let defaults = try Self.defaults()
        let notifier = Self.notifier(log, defaults: defaults)
        await notifier.announce([], account: Self.me)
        await notifier.reset()
        #expect(defaults.data(forKey: "newMailLedger") == nil)
        #expect(await log.badge == 0)
    }
}

private extension MailThread {
    func snoozed(until date: Date) -> MailThread {
        var thread = self
        thread.snoozedUntil = date
        return thread
    }
}

@Suite("Live Activity setting", .serialized)
struct LiveActivitySettingTests {
    @Test func isOnUntilThePersonTurnsItOff() {
        UserDefaults.standard.removeObject(forKey: LiveActivitySetting.key)
        #expect(LiveActivitySetting.isOn)
        LiveActivitySetting.isOn = false
        #expect(!LiveActivitySetting.isOn)
        UserDefaults.standard.removeObject(forKey: LiveActivitySetting.key)
        #expect(LiveActivitySetting.isOn)
    }
}
