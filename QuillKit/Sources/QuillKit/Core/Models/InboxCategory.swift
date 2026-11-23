/// Gmail's inbox tabs. Gmail files each incoming message under exactly one of them.
enum InboxCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case primary, promotions, social, updates, forums

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primary: "Primary"
        case .promotions: "Promotions"
        case .social: "Social"
        case .updates: "Updates"
        case .forums: "Forums"
        }
    }

    /// Gmail's system label for the tab.
    var labelID: String {
        switch self {
        case .primary: "CATEGORY_PERSONAL"
        case .promotions: "CATEGORY_PROMOTIONS"
        case .social: "CATEGORY_SOCIAL"
        case .updates: "CATEGORY_UPDATES"
        case .forums: "CATEGORY_FORUMS"
        }
    }

    init?(labelID: String) {
        guard let match = Self.allCases.first(where: { $0.labelID == labelID }) else { return nil }
        self = match
    }

    static func isCategoryLabel(_ id: String) -> Bool {
        id.hasPrefix("CATEGORY_")
    }
}
