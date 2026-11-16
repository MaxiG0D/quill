import Foundation

enum SnoozeOption: String, CaseIterable, Identifiable, Sendable {
    case laterToday, tomorrow, nextWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .laterToday: "Later Today"
        case .tomorrow: "Tomorrow"
        case .nextWeek: "Next Week"
        }
    }

    var symbol: String {
        switch self {
        case .laterToday: "sun.max"
        case .tomorrow: "sunrise"
        case .nextWeek: "calendar"
        }
    }

    /// When the thread should return: three hours from now, or 8 AM on the chosen day.
    func date(from now: Date, calendar: Calendar) -> Date {
        let morning = { (days: Int) -> Date in
            let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(byAdding: .hour, value: 8, to: day) ?? day
        }
        switch self {
        case .laterToday: return calendar.date(byAdding: .hour, value: 3, to: now) ?? now
        case .tomorrow: return morning(1)
        case .nextWeek: return morning(7)
        }
    }
}
