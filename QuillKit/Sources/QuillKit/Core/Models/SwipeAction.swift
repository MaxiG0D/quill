import Foundation

/// Actions that can be assigned to row swipe gestures.
enum SwipeAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case archive
    case delete
    case unread
    case pin
    case star
    case snooze

    var id: String { rawValue }

    var title: String {
        switch self {
        case .archive: "Archive"
        case .delete: "Delete"
        case .unread: "Mark Read / Unread"
        case .pin: "Pin"
        case .star: "Star"
        case .snooze: "Snooze"
        }
    }

    var symbol: String {
        switch self {
        case .archive: "archivebox"
        case .delete: "trash"
        case .unread: "envelope.badge"
        case .pin: "pin"
        case .star: "star"
        case .snooze: "clock"
        }
    }
}
