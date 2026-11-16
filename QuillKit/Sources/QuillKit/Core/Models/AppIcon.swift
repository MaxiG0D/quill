import Foundation

/// The icons a person can choose for Quill.
///
/// Each case has an app icon set and a preview image, both drawn by
/// `Scripts/render-icons.cjs` from `Design/Icon/icons.json`. Raw values are stored
/// in the person's settings, so they never change.
enum AppIcon: String, CaseIterable, Identifiable, Sendable {
    case paper, paperTerracotta, forest, terracotta, indigo, oxblood, midnight

    /// The icon the app ships with.
    static let primary = AppIcon.paper
    /// The settings key that holds the chosen icon's raw value.
    static let storageKey = "QuillAppIcon"

    var id: Self { self }

    var title: String {
        switch self {
        case .forest: "Forest"
        case .terracotta: "Terracotta"
        case .indigo: "Indigo"
        case .oxblood: "Oxblood"
        case .midnight: "Midnight"
        case .paper: "Paper"
        case .paperTerracotta: "Paper Terracotta"
        }
    }

    /// The icon's name in `icons.json` and in both asset catalogs.
    var assetName: String {
        title.replacing(" ", with: "")
    }

    /// The name of this icon's set in the app's asset catalog, or nil for the primary icon.
    var alternateName: String? {
        self == Self.primary ? nil : "AppIcon-\(assetName)"
    }

    /// The name of this icon's picture in QuillKit's asset catalog.
    var previewName: String {
        "IconPreview-\(assetName)"
    }

    /// The icon the person last chose.
    static func stored(in defaults: UserDefaults = .standard) -> AppIcon {
        defaults.string(forKey: storageKey).flatMap(AppIcon.init) ?? primary
    }
}
