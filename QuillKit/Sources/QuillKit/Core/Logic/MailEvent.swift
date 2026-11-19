import Foundation

/// A date with a time found in a message, such as an appointment, in French or English:
/// "Mercredi le 18 novembre 2026 … 10h20", "Wed, Nov 18 at 10:20 AM", "18/11 de 14h à 15h30".
/// A date alone is not an event, so a message needs both before it gets a card.
struct MailEvent: Hashable, Sendable {
    let start: Date
    /// Nil when the message gives no end; the calendar entry then lasts an hour.
    let end: Date?

    var calendarEnd: Date { end ?? start.addingTimeInterval(3600) }

    /// Still worth adding: it has not ended yet.
    func isUpcoming(at now: Date) -> Bool { calendarEnd > now }

    /// The first event in `text`. A date without a year is taken as the next one after `sentAt`.
    static func find(in text: String, sentAt: Date, calendar: Calendar = .current) -> MailEvent? {
        let folded = String(text.prefix(6000))
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        guard Self.isEventLike(folded) else { return nil }
        let days = Self.days(in: folded, sentAt: sentAt, calendar: calendar)
        guard !days.isEmpty else { return nil }
        let times = Self.times(in: folded)
        guard !times.isEmpty else { return nil }

        for day in days {
            let after = times.first {
                $0.range.location >= NSMaxRange(day.range)
                    && $0.range.location - NSMaxRange(day.range) <= 150
            }
            let before = times.last {
                NSMaxRange($0.range) <= day.range.location
                    && day.range.location - NSMaxRange($0.range) <= 40
            }
            guard let time = after ?? before else { continue }
            guard let start = date(day.components, time.start, calendar) else { continue }
            // A timestamp equal to the send time is the message's own, not an event.
            if calendar.isDate(start, equalTo: sentAt, toGranularity: .minute) { continue }
            var end = time.end.flatMap { date(day.components, $0, calendar) }
            if let finish = end, finish <= start { end = nil }
            return MailEvent(start: start, end: end)
        }
        return nil
    }

    // MARK: Cues

    /// Receipts and payment notices carry transaction timestamps, not events.
    private static let receiptWords = regex(
        #"\b(?:receipts?|purchases?|transactions?|payments?|invoices?|orders?|factures?|recus?|achats?|paiements?|commandes?)\b"#
    )
    private static let eventCues = regex(
        #"\b(?:appointments?|rendez-vous|rdv|remind\w*|rappel|meetings?|reunion|reservations?|webinars?|invit\w*|events?|evenements?|dinner|lunch|diner|souper|dejeuner|party|workshop|conference|call|see you|a bientot|concert|interview|entrevue|session|class|cours|visit\w*)\b"#
    )

    private static func isEventLike(_ text: String) -> Bool {
        matches(receiptWords, text).isEmpty && !matches(eventCues, text).isEmpty
    }

    // MARK: Days

    private struct Day {
        let range: NSRange
        let components: DateComponents
    }

    private static let monthNames: [(String, Int)] = [
        ("january", 1), ("janvier", 1), ("janv", 1), ("jan", 1),
        ("february", 2), ("fevrier", 2), ("fevr", 2), ("fev", 2), ("feb", 2),
        ("march", 3), ("mars", 3), ("mar", 3),
        ("april", 4), ("avril", 4), ("avr", 4), ("apr", 4),
        ("may", 5), ("mai", 5),
        ("june", 6), ("juin", 6), ("jun", 6),
        ("july", 7), ("juillet", 7), ("juil", 7), ("jul", 7),
        ("august", 8), ("aout", 8), ("aug", 8),
        ("september", 9), ("septembre", 9), ("sept", 9), ("sep", 9),
        ("october", 10), ("octobre", 10), ("oct", 10),
        ("november", 11), ("novembre", 11), ("nov", 11),
        ("december", 12), ("decembre", 12), ("dec", 12)
    ]

    /// Longest names first, so "mars" wins over "mar".
    private static let months = monthNames.map(\.0).sorted { $0.count > $1.count }.joined(separator: "|")

    private static let dayFirst = regex(
        #"\b(\d{1,2})(?:er|re|st|nd|rd|th)?\s+(?:of\s+|de\s+)?("# + months + #")\b\.?(?:,?\s+(\d{4})\b)?"#
    )
    /// "Nov 18, 2026". Not "mar 18 nov", where "mar" is the French Tuesday.
    private static let monthFirst = regex(
        #"\b("# + months + #")\b\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b(?!\s*(?:de\s+)?(?:"# + months + #")\b)(?:,?\s+(\d{4})\b)?"#
    )
    private static let iso = regex(#"\b(20\d{2})-(\d{1,2})-(\d{1,2})(?!\d)"#)
    private static let slashed = regex(#"(?<![\d/.])(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?(?![\d/])"#)
    private static let dotted = regex(#"(?<![\d.])(\d{1,2})\.(\d{1,2})\.(\d{4})(?![\d.])"#)
    private static let tomorrow = regex(#"\b(?:tomorrow|demain)\b"#)
    /// French text writes numeric dates day first.
    private static let french = regex(#"\b(?:le|la|les|du|des|votre|vous|nous|rendez-vous|heure|avec)\b"#)

    private static func days(in text: String, sentAt: Date, calendar: Calendar) -> [Day] {
        var found: [Day] = []
        func add(_ range: NSRange, day: Int, month: Int, year: Int?) {
            guard (1...12).contains(month), (1...31).contains(day) else { return }
            let year = year.map { $0 < 100 ? 2000 + $0 : $0 }
            guard let components = resolve(day: day, month: month, year: year, sentAt: sentAt, calendar: calendar)
            else { return }
            found.append(Day(range: range, components: components))
        }

        for match in matches(dayFirst, text) {
            guard let day = int(match, 1, text), let month = month(match, 2, text) else { continue }
            add(match.range, day: day, month: month, year: int(match, 3, text))
        }
        for match in matches(monthFirst, text) {
            guard let month = month(match, 1, text), let day = int(match, 2, text) else { continue }
            add(match.range, day: day, month: month, year: int(match, 3, text))
        }
        for match in matches(iso, text) {
            guard let year = int(match, 1, text), let month = int(match, 2, text), let day = int(match, 3, text)
            else { continue }
            add(match.range, day: day, month: month, year: year)
        }
        for match in matches(dotted, text) {
            guard let day = int(match, 1, text), let month = int(match, 2, text) else { continue }
            add(match.range, day: day, month: month, year: int(match, 3, text))
        }
        let dayFirstNumbers = !matches(french, text).isEmpty
            || Locale.current.region.map { !["US", "CA", "PH"].contains($0.identifier) } ?? true
        for match in matches(slashed, text) {
            guard let first = int(match, 1, text), let second = int(match, 2, text) else { continue }
            let dayFirst = first > 12 || (second <= 12 && dayFirstNumbers)
            add(match.range, day: dayFirst ? first : second, month: dayFirst ? second : first, year: int(match, 3, text))
        }
        for match in matches(tomorrow, text) {
            let next = calendar.date(byAdding: .day, value: 1, to: sentAt) ?? sentAt
            let parts = calendar.dateComponents([.year, .month, .day], from: next)
            found.append(Day(range: match.range, components: parts))
        }

        // Earliest first, and one reading per stretch of text: "le 18 novembre" is not also "novembre 18".
        var kept: [Day] = []
        for day in found.sorted(by: { $0.range.location < $1.range.location }) {
            if let last = kept.last, NSIntersectionRange(last.range, day.range).length > 0 { continue }
            kept.append(day)
        }
        return kept
    }

    /// The day as a full date, picking the year when the message leaves it out.
    private static func resolve(day: Int, month: Int, year: Int?, sentAt: Date, calendar: Calendar) -> DateComponents? {
        func valid(_ year: Int) -> DateComponents? {
            let parts = DateComponents(year: year, month: month, day: day)
            guard let date = calendar.date(from: parts),
                  calendar.component(.day, from: date) == day else { return nil }
            return parts
        }
        if let year { return valid(year) }
        let sentYear = calendar.component(.year, from: sentAt)
        guard let parts = valid(sentYear), let date = calendar.date(from: parts) else { return valid(sentYear + 1) }
        let weekBefore = calendar.date(byAdding: .day, value: -7, to: sentAt) ?? sentAt
        return date < weekBefore ? valid(sentYear + 1) : parts
    }

    // MARK: Times

    private struct Clock {
        var hour: Int
        var minute: Int
        /// "am" or "pm", when given.
        var meridiem: String?

        var hour24: Int {
            switch meridiem {
            case "am"?: hour == 12 ? 0 : hour
            case "pm"?: hour == 12 ? 12 : hour + 12
            default: hour
            }
        }
    }

    private struct Time {
        let range: NSRange
        let start: Clock
        let end: Clock?
    }

    private static let frenchClock = regex(#"(?<![\d:.,/])(\d{1,2})\s?h\s?(\d{2})?(?![\w])"#)
    private static let colonClock = regex(#"(?<![\d:.,/])(\d{1,2}):(\d{2})(?!\d)(?:\s?([ap])\.?m\b\.?)?"#)
    private static let meridiemClock = regex(#"(?<![\d:.,/])(\d{1,2})\s?([ap])\.?m\b\.?"#)
    private static let rangeJoiner = regex(#"^\s*(?:-|\x{2013}|\x{2014}|to|a|au|until|jusqu'?a)\s*$"#)

    private static func times(in text: String) -> [Time] {
        var clocks: [(range: NSRange, clock: Clock)] = []
        for match in matches(frenchClock, text) {
            guard let hour = int(match, 1, text), hour <= 23 else { continue }
            let minute = int(match, 2, text) ?? 0
            guard minute <= 59 else { continue }
            clocks.append((match.range, Clock(hour: hour, minute: minute)))
        }
        for match in matches(colonClock, text) {
            guard let hour = int(match, 1, text), let minute = int(match, 2, text), minute <= 59 else { continue }
            let meridiem = string(match, 3, text).map { $0 + "m" }
            guard meridiem == nil ? hour <= 23 : (1...12).contains(hour) else { continue }
            clocks.append((match.range, Clock(hour: hour, minute: minute, meridiem: meridiem)))
        }
        for match in matches(meridiemClock, text) {
            guard let hour = int(match, 1, text), (1...12).contains(hour), let letter = string(match, 2, text)
            else { continue }
            clocks.append((match.range, Clock(hour: hour, minute: 0, meridiem: letter + "m")))
        }
        clocks.sort { $0.range.location < $1.range.location }

        // "14h à 15h30" and "2:00 - 3:30 pm" are one time with an end.
        var times: [Time] = []
        var index = 0
        while index < clocks.count {
            var start = clocks[index].clock
            if index + 1 < clocks.count {
                let next = clocks[index + 1]
                let gapStart = NSMaxRange(clocks[index].range)
                if next.range.location >= gapStart {
                    let gap = (text as NSString).substring(with: NSRange(location: gapStart, length: next.range.location - gapStart))
                    if matches(rangeJoiner, gap).count == 1 {
                        if start.meridiem == nil, next.clock.meridiem == "pm", start.hour + 12 <= next.clock.hour24 {
                            start.meridiem = "pm"
                        }
                        let range = NSUnionRange(clocks[index].range, next.range)
                        times.append(Time(range: range, start: start, end: next.clock))
                        index += 2
                        continue
                    }
                }
            }
            times.append(Time(range: clocks[index].range, start: start, end: nil))
            index += 1
        }
        return times
    }

    private static func date(_ day: DateComponents, _ clock: Clock, _ calendar: Calendar) -> Date? {
        var parts = day
        parts.hour = clock.hour24
        parts.minute = clock.minute
        return calendar.date(from: parts)
    }

    // MARK: Matching

    private static func matches(_ expression: NSRegularExpression, _ text: String) -> [NSTextCheckingResult] {
        expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func string(_ match: NSTextCheckingResult, _ group: Int, _ text: String) -> String? {
        let range = match.range(at: group)
        guard range.location != NSNotFound, let bounds = Range(range, in: text) else { return nil }
        return String(text[bounds])
    }

    private static func int(_ match: NSTextCheckingResult, _ group: Int, _ text: String) -> Int? {
        string(match, group, text).flatMap { Int($0) }
    }

    private static func month(_ match: NSTextCheckingResult, _ group: Int, _ text: String) -> Int? {
        guard let name = string(match, group, text) else { return nil }
        return monthNames.first { $0.0 == name }?.1
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // The patterns are constants, checked by the tests.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
