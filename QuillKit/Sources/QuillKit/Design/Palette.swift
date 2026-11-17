import SwiftUI

/// The color tokens from the design's Tokens page.
///
/// Roles: accent marks unread mail, pins and counts. Warm is for Compose and stars.
/// Destructive is for Delete.
enum Palette {
    static let background = Color(light: 0xF5F6F3, dark: 0x0B100F)
    static let surface = Color(light: 0xFFFFFF, dark: 0x141A19)
    static let fill = Color(light: 0xECEEE9, dark: 0x1D2523)
    static let separator = Color(light: 0xE1E4DE, dark: 0x27312E)
    static let label = Color(light: 0x151918, dark: 0xEDF1EF)
    static let secondaryLabel = Color(light: 0x5D6561, dark: 0x94A09B)
    /// The preview line of mail that has been read.
    static let tertiaryLabel = Color(light: 0x737B77, dark: 0x7A8580)
    static let accent = Color(light: 0x0B6E69, dark: 0x4CC2B5)
    static let accentFill = Color(light: 0x0B6E69, dark: 0x0F7A71)
    static let accentTint = Color(light: 0xDCECE8, dark: 0x14302C)
    static let warm = Color(light: 0xB8501F, dark: 0xF2A274)
    static let warmFill = Color(light: 0xC4562A, dark: 0xC4562A)
    static let destructive = Color(light: 0xC62828, dark: 0xFF7A72)
    static let destructiveFill = Color(light: 0xC62828, dark: 0xC93434)
    static let neutralFill = Color(light: 0x5D6561, dark: 0x3C4744)

    /// Text and glyphs that sit on a filled accent, warm or destructive surface.
    static let onFill = Color.white
    /// The top of the Inbox header gradient, which fades into `background`.
    static let heroTop = Color(light: 0xD8EAE5, dark: 0x153F39)
}
