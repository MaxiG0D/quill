import SwiftUI

struct TextRoleModifier: ViewModifier {
    let role: TextRole

    // The serif display sizes are fixed in the design, so they scale by hand with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var displaySize = Self.displayBase
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = Self.titleBase

    func body(content: Content) -> some View {
        content
            .font(font)
            .tracking(tracking)
    }

    #if os(macOS)
    private static let displayBase = 26.0
    private static let titleBase = 38.0

    // macOS has no Dynamic Type, and its text styles run small, so sizes are set directly.
    private var font: Font {
        switch role {
        case .display: .system(size: displaySize, weight: .semibold, design: .serif)
        case .title: .system(size: titleSize, weight: .semibold, design: .serif)
        case .section: .system(size: 17, weight: .semibold, design: .serif)
        case .count: .system(size: 18, design: .serif).italic()
        case .sender(let unread): .system(size: 13, weight: unread ? .bold : .semibold)
        case .subject(let unread): .system(size: 13, weight: unread ? .semibold : .regular)
        case .preview: .system(size: 12)
        case .meta: .system(size: 11).monospacedDigit()
        case .reading: .system(size: 17)
        case .chip: .system(size: 11, weight: .semibold)
        }
    }
    #else
    private static let displayBase = 46.0
    private static let titleBase = 34.0

    private var font: Font {
        switch role {
        case .display: .system(size: displaySize, weight: .semibold, design: .serif)
        case .title: .system(size: titleSize, weight: .semibold, design: .serif)
        case .section: .system(.title3, design: .serif, weight: .semibold)
        case .count: .system(.title2, design: .serif).italic()
        case .sender(let unread): .callout.weight(unread ? .bold : .semibold)
        case .subject(let unread): .subheadline.weight(unread ? .semibold : .regular)
        case .preview: .footnote
        case .meta: .caption.monospacedDigit()
        case .reading: .body
        case .chip: .caption.weight(.semibold)
        }
    }
    #endif

    private var tracking: Double {
        switch role {
        case .display: displaySize * -0.026
        case .title: titleSize * -0.026
        case .section: -0.3
        default: 0
        }
    }
}
