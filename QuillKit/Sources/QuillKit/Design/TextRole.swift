import SwiftUI

/// The type roles from the Tokens page.
enum TextRole {
    /// The mailbox title.
    case display
    /// A thread's subject, and sheet titles.
    case title
    /// Section headers such as Today.
    case section
    /// The italic unread count beside the title.
    case count
    case sender(unread: Bool)
    case subject(unread: Bool)
    case preview
    /// Times and counts, with digits that do not shift.
    case meta
    /// The text of an open message.
    case reading
    case chip
}

extension View {
    func textRole(_ role: TextRole) -> some View {
        modifier(TextRoleModifier(role: role))
    }
}
