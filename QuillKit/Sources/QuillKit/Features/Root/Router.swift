import Foundation
import Observation

/// Where the person is in the app: the pushed thread, open sheets and search.
@MainActor
@Observable
final class Router {
    /// The compact layout's navigation path.
    var path: [MailThread.ID] = []
    /// The message being written. Setting it presents the composer.
    var draft: Draft?
    /// The thread whose custom snooze date/time picker is open.
    var snoozingThreadID: MailThread.ID?
    /// A downloaded attachment file URL presented in QuickLook from the Inbox or thread.
    var previewAttachmentURL: URL?
    var isShowingMailboxes = false
    var isShowingSettings = false
    var isSearching = false

    /// Clears transient navigation and sheet state (for example on sign-out).
    func reset() {
        path = []
        draft = nil
        snoozingThreadID = nil
        previewAttachmentURL = nil
        isShowingMailboxes = false
        isShowingSettings = false
        isSearching = false
    }
}
