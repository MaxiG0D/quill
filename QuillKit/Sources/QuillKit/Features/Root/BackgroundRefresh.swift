#if os(iOS)
import BackgroundTasks
#endif
import Foundation

/// The system's periodic chance for Quill to look for new mail while it is in the
/// background on iPhone and iPad. A Mac keeps looking for as long as Quill is running.
enum BackgroundRefresh {
    /// Also listed under `BGTaskSchedulerPermittedIdentifiers` in `App/Info.plist`.
    static let identifier = "com.maxig0d.quill.refresh"
    /// The soonest the system is asked to come back. It chooses the actual moment.
    private static let interval: TimeInterval = 15 * 60

    /// Asks for the next chance. Each request is good for one.
    static func schedule() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }
}
