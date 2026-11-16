/// Whether the system lets Quill show notifications.
enum NotificationPermission: Sendable {
    /// The person has not been asked yet.
    case undecided
    case allowed
    case denied
}
