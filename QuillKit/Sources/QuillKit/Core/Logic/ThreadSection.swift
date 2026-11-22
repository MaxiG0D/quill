import Foundation

/// A dated group of threads in the list.
struct ThreadSection: Identifiable, Hashable, Sendable {
    enum Kind: Int, CaseIterable, Sendable {
        case pinned, today, yesterday, thisWeek, earlier

        var title: String {
            switch self {
            case .pinned: "Pinned"
            case .today: "Today"
            case .yesterday: "Yesterday"
            case .thisWeek: "This Week"
            case .earlier: "Earlier"
            }
        }
    }

    let kind: Kind
    var threads: [MailThread]

    var id: Kind { kind }

    /// Groups threads into Pinned, Today, Yesterday, This Week and Earlier, newest first.
    /// Empty groups are left out.
    static func sections(
        for threads: [MailThread],
        now: Date,
        calendar: Calendar,
        pinsFirst: Bool = true
    ) -> [ThreadSection] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        var groups: [Kind: [MailThread]] = [:]
        for thread in threads.sorted(by: { $0.displayDate(at: now) > $1.displayDate(at: now) }) {
            let effectiveDate = thread.displayDate(at: now)
            let kind: Kind =
                if pinsFirst && thread.isPinned {
                    .pinned
                } else if effectiveDate >= today {
                    .today
                } else if effectiveDate >= yesterday {
                    .yesterday
                } else if effectiveDate >= weekAgo {
                    .thisWeek
                } else {
                    .earlier
                }
            groups[kind, default: []].append(thread)
        }

        return Kind.allCases.compactMap { kind in
            groups[kind].map { ThreadSection(kind: kind, threads: $0) }
        }
    }
}
