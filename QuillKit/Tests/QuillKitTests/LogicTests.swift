import Foundation
import Testing
@testable import QuillKit

struct LogicTests {
    @Test func inboxGroupsIntoTheSectionsTheMockupShows() {
        let inbox = Fixture.snapshot.threads.filter { $0.belongs(to: .mailbox(.inbox), at: Fixture.now) }
        let sections = ThreadSection.sections(for: inbox, now: Fixture.now, calendar: Fixture.calendar)

        #expect(sections.map(\.kind) == [.pinned, .today, .yesterday, .thisWeek])
        #expect(sections[0].threads.map(\.id) == ["lease-renewal"])
        #expect(sections[1].threads.map(\.id) == ["dental", "library"])
        #expect(sections[2].threads.map(\.id) == ["hike", "thanksgiving"])
        #expect(sections[3].threads.map(\.id) == ["photos", "water"])
    }

    @Test func pinnedThreadsFallIntoDatedSectionsOutsideTheInbox() {
        let threads = Fixture.snapshot.threads.filter { $0.id == "lease-renewal" }
        let sections = ThreadSection.sections(for: threads, now: Fixture.now, calendar: Fixture.calendar, pinsFirst: false)
        #expect(sections.map(\.kind) == [.today])
    }

    @Test func shortTimestampsFollowTheAgeOfTheMessage() {
        let stamp = MailTimestamp(now: Fixture.now, calendar: Fixture.calendar, locale: Locale(identifier: "en_US"))
        // Times use a narrow no-break space before AM and PM.
        let plain = { (date: Date) in stamp.short(date).replacing("\u{202F}", with: " ") }

        #expect(plain(Fixture.date(daysAgo: 0, hour: 9, minute: 12)) == "9:12 AM")
        #expect(plain(Fixture.date(daysAgo: 1, hour: 18, minute: 4)) == "6:04 PM")
        #expect(plain(Fixture.date(daysAgo: 3, hour: 9)) == "Mon")
        #expect(plain(Fixture.date(daysAgo: 16, hour: 9)) == "Oct 28")
        #expect(plain(Fixture.date(daysAgo: 91, hour: 9)) == "8/14/25")
    }

    @Test func longTimestampsNameTodayAndYesterday() {
        let stamp = MailTimestamp(now: Fixture.now, calendar: Fixture.calendar, locale: Locale(identifier: "en_US"))
        let plain = { (date: Date) in stamp.long(date).replacing("\u{202F}", with: " ") }

        #expect(plain(Fixture.date(daysAgo: 0, hour: 9, minute: 12)) == "Today, 9:12 AM")
        #expect(plain(Fixture.date(daysAgo: 1, hour: 18, minute: 4)) == "Yesterday, 6:04 PM")
        #expect(plain(Fixture.date(daysAgo: 16, hour: 15, minute: 20)) == "Oct 28, 3:20 PM")
    }

    @Test func matcherFindsEveryWordIgnoringCaseAndAccents() {
        let text = "Lease renewal for the café lease"
        let ranges = TextMatcher.ranges(of: "LEASE cafe", in: text)
        #expect(ranges.map { String(text[$0]) } == ["Lease", "café", "lease"])
    }

    @Test func matcherMergesOverlappingMatches() {
        let text = "release"
        let ranges = TextMatcher.ranges(of: "lease release", in: text)
        #expect(ranges.map { String(text[$0]) } == ["release"])
    }

    @Test func matcherNeedsEveryWord() {
        #expect(TextMatcher.matches("lease scan", in: "Signed lease scan"))
        #expect(!TextMatcher.matches("lease invoice", in: "Signed lease scan"))
        #expect(!TextMatcher.matches("   ", in: "Signed lease scan"))
    }

    @Test func excerptKeepsALateMatchInView() {
        let text = "Your old place is ready and the paperwork says the lease ends the same day."
        let excerpt = TextMatcher.excerpt(of: text, around: "lease")
        #expect(excerpt.hasPrefix("…"))
        #expect(excerpt.contains("lease ends"))
        #expect(TextMatcher.excerpt(of: "Lease first", around: "lease") == "Lease first")
    }

    @Test func searchReturnsTheMockupResultsNewestFirst() {
        let results = MailSearch.results(for: "lease", in: Fixture.snapshot.threads)
        #expect(results.map(\.id) == [
            "lease-renewal", "lease-questions", "lease-scan", "lease-unit", "lease-draft", "movers"
        ])
    }

    @Test func searchSkipsTrashAndEmptyQueries() {
        var threads = Fixture.snapshot.threads
        for index in threads.indices where threads[index].id == "movers" {
            threads[index].folder = .trash
        }
        #expect(!MailSearch.results(for: "lease", in: threads).map(\.id).contains("movers"))
        #expect(MailSearch.results(for: "  ", in: threads).isEmpty)
    }

    @Test func snoozeOptionsLandOnSensibleTimes() {
        let calendar = Fixture.calendar
        let tomorrow = SnoozeOption.tomorrow.date(from: Fixture.now, calendar: calendar)
        #expect(calendar.component(.hour, from: tomorrow) == 8)
        #expect(calendar.dateComponents([.day], from: calendar.startOfDay(for: Fixture.now), to: tomorrow).day == 1)
        #expect(SnoozeOption.laterToday.date(from: Fixture.now, calendar: calendar) == Fixture.now.addingTimeInterval(3 * 3600))
    }
}
