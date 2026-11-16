import SwiftUI

/// The paragraph styles offered by the format bar's text menu.
enum ComposeTextStyle: String, CaseIterable, Identifiable {
    case heading, body, small

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heading: "Heading"
        case .body: "Body"
        case .small: "Small"
        }
    }

    var font: Font {
        switch self {
        case .heading: .system(.title3, design: .serif, weight: .semibold)
        case .body: .body
        case .small: .footnote
        }
    }
}
