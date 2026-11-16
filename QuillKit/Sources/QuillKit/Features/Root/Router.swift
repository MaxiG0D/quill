import Observation

/// Where the person is in the app: the pushed thread, open sheets and search.
@MainActor
@Observable
final class Router {
    /// The compact layout's navigation path.
    var path: [MailThread.ID] = []
    /// The message being written. Setting it presents the composer.
    var draft: Draft?
    var isShowingMailboxes = false
    var isShowingSettings = false
    var isSearching = false
}
