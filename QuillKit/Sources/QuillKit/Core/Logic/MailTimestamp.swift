import Foundation

/// Formats message dates the way the lists and headers show them.
struct MailTimestamp: Sendable {
    var now: Date
    var calendar: Calendar = .current
    var locale: Locale = .current

    /// How long a date keeps its month-and-day form before switching to numbers.
    private static let recentDays = 60

    /// The short form for rows: "9:12 AM" today and yesterday, "Mon" this week,
    /// "Oct 28" for recent mail, and "8/14/25" for anything older.
    func short(_ date: Date) -> String {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let recent = calendar.date(byAdding: .day, value: -Self.recentDays, to: today) ?? today

        if date >= yesterday {
            return date.formatted(style(Date.FormatStyle(date: .omitted, time: .shortened)))
        } else if date >= weekAgo {
            return date.formatted(style(.dateTime.weekday(.abbreviated)))
        } else if date >= recent {
            return date.formatted(style(.dateTime.month(.abbreviated).day()))
        } else {
            return date.formatted(
                style(.dateTime.month(.defaultDigits).day(.defaultDigits).year(.twoDigits))
            )
        }
    }

    /// The long form for an open message: "Today, 9:12 AM" or "Oct 28, 9:12 AM".
    func long(_ date: Date) -> String {
        let time = date.formatted(style(Date.FormatStyle(date: .omitted, time: .shortened)))
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let day: String
        if date >= today {
            day = String(localized: "Today")
        } else if date >= yesterday {
            day = String(localized: "Yesterday")
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            day = date.formatted(style(.dateTime.month(.abbreviated).day()))
        } else {
            day = date.formatted(style(.dateTime.month(.abbreviated).day().year()))
        }
        return "\(day), \(time)"
    }

    private func style(_ base: Date.FormatStyle) -> Date.FormatStyle {
        var style = base
        style.calendar = calendar
        style.locale = locale
        style.timeZone = calendar.timeZone
        return style
    }
}
