import Foundation
@testable import QuillKit

/// A fixed calendar and moment so tests do not depend on where or when they run.
enum Fixture {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto") ?? .gmt
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    static var now: Date { SampleData.referenceDate(in: calendar) }

    static var snapshot: MailSnapshot { SampleData.snapshot(now: now, calendar: calendar) }

    @MainActor
    static func store() -> MailStore {
        let now = now
        return MailStore(snapshot: snapshot, calendar: calendar, clock: { now })
    }

    static func date(daysAgo: Int, hour: Int, minute: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
