import Foundation
import Observation
import os

/// The app's mailbox state and every action that changes it.
///
/// Changes are applied here first so the interface responds at once, then sent to the
/// `MailService`. If the service rejects one, the change is rolled back and `alert` is set.
@MainActor
@Observable
final class MailStore {
    private(set) var phase: LoadPhase = .idle
    private(set) var account: Contact
    private(set) var labels: [MailLabel] = []
    private(set) var threads: [MailThread] = []
    /// How much of the mailbox has arrived, from 0 to 1, while it is still arriving. Nil once it is all here.
    private(set) var syncProgress: Double?

    var selection: MailboxSelection = .mailbox(.inbox)
    var filter: InboxFilter = .all
    /// The open thread in the three-column layout.
    var selectedThreadID: MailThread.ID?
    /// Multi-selection state for bulk triage on iOS and macOS.
    var isSelecting = false
    var selectedThreadIDs: Set<MailThread.ID> = []

    var searchQuery = ""
    var searchFilter: InboxFilter = .all
    private(set) var recentSearches: [String] = []
    private(set) var searchResults: [SearchResult] = []
    private(set) var isSearching = false
    /// Pagination state for the active mailbox or label.
    private(set) var hasMoreThreads = false
    private(set) var isLoadingMore = false
    /// Advances when the next snoozed thread's wake time arrives so views refresh.
    private(set) var snoozeTick = Date.distantPast
    /// Set when the user undoes a scheduled send, so `RootView` reopens the draft in `ComposeView`.
    var cancelledDraft: Draft?

    private(set) var toast: UndoToast?
    /// Senders the person has unsubscribed from, by lowercased address.
    private(set) var unsubscribed: Set<String>
    private(set) var haptic: HapticCue?
    /// A failure the person should hear about.
    var alert: String?

    let calendar: Calendar
    private let service: any MailService
    private let notifier: MailNotifier?
    private let clock: @Sendable () -> Date
    /// Where `unsubscribed` is kept between launches. Nil keeps it in memory.
    private let defaults: UserDefaults?
    private static let unsubscribedKey = "unsubscribedSenders"
    private static let recentSearchesKey = "recentSearches"
    private var searchTask: Task<Void, Never>?
    /// Thread IDs matched by the mail service for the current search query, kept even when
    /// Gmail matched text outside the local preview (such as an HTML body or email address).
    private var remoteSearchIDs: Set<MailThread.ID> = []
    private var pendingMutations: [MailThread.ID: Task<Void, Never>] = [:]
    private var mutationGenerations: [MailThread.ID: Int] = [:]
    private var snoozeWakeTask: Task<Void, Never>?
    private var pendingSendTask: Task<Void, Never>?
    private var pendingSendDraft: Draft?
    private var downloadedAttachments: [Attachment.ID: URL] = [:]
    private var isFetching = false
    /// Set when a mailbox was opened mid-fetch and needs a fetch of its own afterwards.
    private var isFetchQueued = false
    private var continuation: Task<Void, Never>?
    /// The wait before asking again for a mailbox that is still arriving. It doubles each
    /// time the service has nothing new, up to eight times its starting length.
    private let retryDelay: Duration
    private var waits = 0
    private static let log = Logger(subsystem: "com.maxig0d.quill", category: "mail")

    init(
        service: any MailService,
        notifier: MailNotifier? = nil,
        calendar: Calendar = .current,
        clock: @escaping @Sendable () -> Date = { .now },
        retryDelay: Duration = .seconds(30),
        defaults: UserDefaults? = .standard
    ) {
        self.defaults = defaults
        self.unsubscribed = Set(defaults?.stringArray(forKey: Self.unsubscribedKey) ?? [])
        self.recentSearches = defaults?.stringArray(forKey: Self.recentSearchesKey) ?? []
        self.service = service
        self.notifier = notifier
        self.calendar = calendar
        self.clock = clock
        self.retryDelay = retryDelay
        self.account = Contact(name: "", email: "")
    }

    /// A store that starts loaded, for previews, tests and screenshots.
    convenience init(
        snapshot: MailSnapshot,
        calendar: Calendar = .current,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.init(
            service: SampleMailService(snapshot: snapshot, latency: .zero),
            calendar: calendar,
            clock: clock,
            defaults: nil
        )
        adopt(snapshot)
    }

    // MARK: Reading

    var now: Date { clock() }

    var timestamp: MailTimestamp {
        MailTimestamp(now: now, calendar: calendar)
    }

    var title: String {
        switch selection {
        case .mailbox(let mailbox): mailbox.title
        case .label(let id): label(id)?.name ?? ""
        }
    }

    var isInbox: Bool { selection == .mailbox(.inbox) }

    /// Threads in the current mailbox that pass the filter, newest first.
    var visibleThreads: [MailThread] {
        _ = snoozeTick
        let now = self.now
        return threads
            .filter { $0.belongs(to: selection, at: now) && filter.matches($0) }
            .sorted { $0.displayDate(at: now) > $1.displayDate(at: now) }
    }

    var sections: [ThreadSection] {
        ThreadSection.sections(for: visibleThreads, now: now, calendar: calendar, pinsFirst: isInbox)
    }

    /// The number shown beside the title: unread threads in the current mailbox.
    var unreadCount: Int {
        _ = snoozeTick
        let now = self.now
        return threads.count { $0.belongs(to: selection, at: now) && $0.isUnread }
    }

    /// The number shown beside a mailbox or label, or nil when there is nothing to show.
    func badge(for selection: MailboxSelection) -> Int? {
        _ = snoozeTick
        let now = self.now
        let members = threads.filter { $0.belongs(to: selection, at: now) }
        let count =
            switch selection {
            case .mailbox(.snoozed), .mailbox(.drafts): members.count
            case .mailbox(.inbox), .label: members.count(where: \.isUnread)
            case .mailbox: 0
            }
        return count > 0 ? count : nil
    }

    func thread(_ id: MailThread.ID?) -> MailThread? {
        guard let id else { return nil }
        return threads.first { $0.id == id }
    }

    func label(_ id: MailLabel.ID) -> MailLabel? {
        labels.first { $0.id == id }
    }

    /// A thread's labels, in the account's order.
    func labels(for thread: MailThread) -> [MailLabel] {
        labels.filter { thread.labelIDs.contains($0.id) }
    }

    /// The number shown beside the title: matches the sidebar badge for Drafts and Snoozed,
    /// and shows unread threads elsewhere.
    var headerCount: Int {
        switch selection {
        case .mailbox(.drafts), .mailbox(.snoozed):
            badge(for: selection) ?? 0
        default:
            unreadCount
        }
    }

    /// The unread thread IDs currently in the Inbox, used to keep delivered notifications in step.
    var unreadInboxIDs: [MailThread.ID] {
        let now = self.now
        return threads
            .filter { $0.isUnread && $0.belongs(to: .mailbox(.inbox), at: now) }
            .map(\.id)
            .sorted()
    }

    /// True when the search query contains at least one non-whitespace character.
    var hasSearchQuery: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Everyone who appears in the mailbox, for recipient suggestions.
    var knownContacts: [Contact] {
        let me = account.email.lowercased()
        var seen = Set<String>()
        return threads
            .flatMap { $0.messages.flatMap { [$0.sender] + $0.to + $0.cc } }
            .filter { contact in
                let email = contact.email.lowercased()
                return !email.isEmpty && email != me && seen.insert(email).inserted
            }
    }

    // MARK: Loading

    /// Shows the mailbox as last seen, if the service kept one, then brings it up to date.
    func load() async {
        switch phase {
        case .loading, .loaded: return
        case .idle, .failed: phase = .loading
        }
        if let cached = await service.cachedSnapshot() {
            adopt(cached)
        }
        await fetch(isQuiet: false)
    }

    /// Brings the mailbox up to date. A quiet refresh, such as one on returning to the app, keeps failures to itself.
    func refresh(isQuiet: Bool = false) async {
        await fetch(isQuiet: isQuiet)
    }

    /// Puts mail a notification announced on screen at once, by fetching just those threads,
    /// so it is already there when the person arrives and the full refresh has yet to finish.
    func bringIn(arrived ids: [MailThread.ID]) async {
        if phase == .idle, let cached = await service.cachedSnapshot() {
            adopt(cached)
        }
        guard phase == .loaded else { return }
        for id in ids where !id.isEmpty {
            guard let snapshot = try? await service.fetchThread(id) else { continue }
            adopt(snapshot)
        }
    }

    /// Brings the mailbox up to date while no one is looking, keeping any failure to itself.
    /// It starts from the mailbox as last seen when the app was opened by the system, not the person.
    func refreshUnseen() async {
        if phase == .idle, let cached = await service.cachedSnapshot() {
            adopt(cached)
        }
        guard phase == .loaded else { return }
        await fetch(isQuiet: true)
    }

    private func fetch(isQuiet: Bool) async {
        // A fetch already under way may have started before the change that prompted this one,
        // so it is followed by another rather than this request being dropped.
        guard !isFetching else {
            isFetchQueued = true
            return
        }
        isFetching = true
        defer { isFetching = false }
        await fetchOnce(isQuiet: isQuiet)
        while isFetchQueued {
            isFetchQueued = false
            await fetchOnce(isQuiet: true)
        }
    }

    private func fetchOnce(isQuiet: Bool) async {
        do {
            let snapshot = try await service.snapshot()
            let hasNews = snapshot.threads != threads
            adopt(snapshot)
            syncProgress = snapshot.isComplete ? nil : snapshot.progress
            if snapshot.isComplete {
                waits = 0
            } else {
                continueLoading(isWaitingLonger: !hasNews)
            }
            await notifier?.announce(snapshot.threads, account: snapshot.account)
        } catch GmailError.rateLimited {
            // The service's allowance refills by itself, so this is never the person's
            // problem: whatever is on screen stays, and the fetch is tried again later.
            Self.log.info("Mail service is rate limited; trying again later")
            syncProgress = syncProgress ?? 0
            continueLoading(isWaitingLonger: true)
        } catch {
            Self.log.error("Mail could not be loaded: \(String(describing: error), privacy: .public)")
            syncProgress = nil
            if threads.isEmpty && phase != .loaded {
                phase = .failed(Self.describe(error))
            } else if !isQuiet {
                alert = Self.describe(error)
            }
        }
    }

    /// Fetches the next part of a mailbox that is arriving in passes, once the service's
    /// allowance has had time to refill.
    private func continueLoading(isWaitingLonger: Bool) {
        waits = isWaitingLonger ? min(waits + 1, 4) : 1
        // A little randomness keeps several devices on one account from asking in step.
        let delay = retryDelay * Double(1 << (waits - 1)) * Double.random(in: 1...1.3)
        continuation?.cancel()
        continuation = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.fetch(isQuiet: true)
        }
    }

    /// An error in words. A decoding failure says which field it tripped on, which its
    /// localized description leaves out.
    private static func describe(_ error: any Error) -> String {
        error is DecodingError ? "Unexpected reply from the mail service. \(error)" : error.localizedDescription
    }

    private func adopt(_ snapshot: MailSnapshot) {
        account = snapshot.account
        labels = snapshot.labels
        threads = snapshot.threads
        phase = .loaded
        scheduleSnoozeWake()
        refreshHasMore()
        if hasSearchQuery {
            refreshSearchResults()
        }
    }

    /// Schedules a wake-up for the earliest upcoming snooze so threads return to Inbox on time.
    private func scheduleSnoozeWake() {
        snoozeWakeTask?.cancel()
        let now = self.now
        guard let nextWake = threads
            .compactMap(\.snoozedUntil)
            .filter({ $0 > now })
            .min() else {
            snoozeWakeTask = nil
            return
        }
        let delay = max(nextWake.timeIntervalSince(now), 0) + 0.5
        // Cap individual sleeps to 1 hour so long snoozes don't hold giant timers.
        let sleepSeconds = min(delay, 3600)
        snoozeWakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(sleepSeconds))
            guard !Task.isCancelled, let self else { return }
            self.snoozeTick = self.now
            self.scheduleSnoozeWake()
        }
    }

    // MARK: Triage

    func toggleStar(_ id: MailThread.ID) {
        guard let thread = thread(id) else { return }
        commit(.setStarred(!thread.isStarred), to: id, cue: .selection)
    }

    func togglePin(_ id: MailThread.ID) {
        guard let thread = thread(id) else { return }
        commit(.setPinned(!thread.isPinned), to: id, cue: .selection)
    }

    func toggleUnread(_ id: MailThread.ID) {
        guard let thread = thread(id) else { return }
        commit(.setUnread(!thread.isUnread), to: id, cue: .selection)
    }

    /// Marks a thread read when it is opened, and clears a returned-snooze badge once read.
    func markRead(_ id: MailThread.ID) {
        guard let thread = thread(id) else { return }
        if thread.isUnread {
            commit(.setUnread(false), to: id, cue: nil)
        }
        if thread.hasReturned(at: now) {
            commit(.snooze(nil), to: id, cue: nil)
        }
    }

    /// Marks every unread thread in `target` (or the current mailbox) as read.
    func markAllRead(in target: MailboxSelection? = nil) {
        let target = target ?? selection
        let now = self.now
        let unreadIDs = threads
            .filter { $0.belongs(to: target, at: now) && $0.isUnread }
            .map(\.id)
        guard !unreadIDs.isEmpty else { return }
        for id in unreadIDs {
            commit(.setUnread(false), to: id, cue: nil)
        }
        haptic = HapticCue(kind: .selection)
    }

    /// Permanently deletes a thread (used in Trash). Cannot be undone.
    func deletePermanently(_ id: MailThread.ID) {
        guard let previous = thread(id) else { return }
        deselect(id)
        threads.removeAll { $0.id == id }
        if hasSearchQuery { refreshSearchResults() }
        haptic = HapticCue(kind: .warning)
        Task {
            do {
                try await service.deletePermanently([id])
            } catch {
                if !threads.contains(where: { $0.id == previous.id }) {
                    threads.append(previous)
                }
                alert = error.localizedDescription
            }
        }
    }

    /// Permanently deletes every thread in Trash.
    func emptyTrash() {
        let trashed = threads.filter { $0.folder == .trash }
        guard !trashed.isEmpty else { return }
        let ids = trashed.map(\.id)
        let idSet = Set(ids)
        if let selected = selectedThreadID, idSet.contains(selected) {
            selectedThreadID = nil
        }
        threads.removeAll { idSet.contains($0.id) }
        haptic = HapticCue(kind: .warning)
        Task {
            do {
                try await service.deletePermanently(ids)
            } catch {
                let existing = Set(threads.map(\.id))
                threads += trashed.filter { !existing.contains($0.id) }
                alert = error.localizedDescription
            }
        }
    }

    /// Moves a thread to Gmail's Spam folder, with Undo.
    func markAsSpam(_ id: MailThread.ID) {
        guard let previous = thread(id) else { return }
        deselect(id)
        threads.removeAll { $0.id == id }
        if hasSearchQuery { refreshSearchResults() }
        haptic = HapticCue(kind: .warning)
        toast = UndoToast(title: "Marked as Spam", symbol: "exclamationmark.octagon", previous: [previous])
        Task {
            do {
                try await service.markSpam([id], isSpam: true)
            } catch {
                if !threads.contains(where: { $0.id == previous.id }) {
                    threads.append(previous)
                    if hasSearchQuery { refreshSearchResults() }
                }
                alert = error.localizedDescription
            }
        }
    }

    /// Downloads the raw bytes of an attachment for preview or sharing.
    func attachmentData(for attachment: Attachment) async throws -> Data {
        try await service.attachmentData(for: attachment)
    }

    /// Downloads an attachment to a temporary file URL (cached per session) for QuickLook or sharing.
    func previewFileURL(for attachment: Attachment) async throws -> URL {
        if let cached = downloadedAttachments[attachment.id], FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }
        let data = try await attachmentData(for: attachment)
        let safeFolder = attachment.id.replacing("/", with: "_")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuillAttachments", isDirectory: true)
            .appendingPathComponent(safeFolder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeName = (attachment.filename as NSString).lastPathComponent
        let fileURL = directory.appendingPathComponent(safeName.isEmpty ? "attachment" : safeName)
        try data.write(to: fileURL, options: .atomic)
        downloadedAttachments[attachment.id] = fileURL
        return fileURL
    }

    // MARK: Multi-select & Bulk Triage

    func toggleSelection(_ id: MailThread.ID) {
        if selectedThreadIDs.contains(id) {
            selectedThreadIDs.remove(id)
        } else {
            selectedThreadIDs.insert(id)
        }
        haptic = HapticCue(kind: .selection)
    }

    /// Extends multi-selection from the last active thread to `id` (for Shift-click on macOS).
    func selectRange(to id: MailThread.ID) {
        let ids = orderedVisibleIDs
        let anchor = selectedThreadID ?? selectedThreadIDs.first
        guard let anchor, let start = ids.firstIndex(of: anchor), let end = ids.firstIndex(of: id) else {
            toggleSelection(id)
            return
        }
        let range = min(start, end)...max(start, end)
        selectedThreadIDs.formUnion(ids[range])
        haptic = HapticCue(kind: .selection)
    }

    func selectAllVisible() {
        selectedThreadIDs = Set(orderedVisibleIDs)
    }

    func clearSelection() {
        isSelecting = false
        selectedThreadIDs = []
    }

    func trash(_ ids: [MailThread.ID]) {
        let moving = ids.compactMap(thread).filter { $0.folder != .trash }
        guard !moving.isEmpty else { return }
        for thread in moving {
            if willLeaveCurrentList(thread.id, after: .move(.trash)) {
                deselect(thread.id)
            }
            commit(.move(.trash), to: thread.id, cue: nil)
        }
        clearSelection()
        haptic = HapticCue(kind: .warning)
        let title = moving.count == 1 ? "Moved to Trash" : "Deleted \(moving.count)"
        toast = UndoToast(title: title, symbol: Mailbox.trash.symbol, previous: moving)
    }

    func markUnread(_ ids: [MailThread.ID], isUnread: Bool) {
        for id in ids where thread(id)?.isUnread != isUnread {
            commit(.setUnread(isUnread), to: id, cue: nil)
        }
        clearSelection()
        haptic = HapticCue(kind: .selection)
    }

    func setStarred(_ ids: [MailThread.ID], isStarred: Bool) {
        for id in ids where thread(id)?.isStarred != isStarred {
            commit(.setStarred(isStarred), to: id, cue: nil)
        }
        clearSelection()
        haptic = HapticCue(kind: .selection)
    }

    // MARK: Labels

    func createLabel(named rawName: String) async {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            let created = try await service.createLabel(name: name)
            labels.append(created)
            labels.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            haptic = HapticCue(kind: .success)
        } catch {
            alert = error.localizedDescription
            haptic = HapticCue(kind: .warning)
        }
    }

    func renameLabel(_ id: MailLabel.ID, to rawName: String) async {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            let updated = try await service.renameLabel(id, to: name)
            if let index = labels.firstIndex(where: { $0.id == id }) {
                labels[index] = updated
                labels.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
            haptic = HapticCue(kind: .selection)
        } catch {
            alert = error.localizedDescription
            haptic = HapticCue(kind: .warning)
        }
    }

    func deleteLabel(_ id: MailLabel.ID) async {
        do {
            try await service.deleteLabel(id)
            labels.removeAll { $0.id == id }
            for index in threads.indices {
                threads[index].labelIDs.removeAll { $0 == id }
            }
            if selection == .label(id) {
                show(.mailbox(.inbox))
            }
            haptic = HapticCue(kind: .warning)
        } catch {
            alert = error.localizedDescription
            haptic = HapticCue(kind: .warning)
        }
    }

    /// Loads the next page of older mail for the current mailbox or label.
    func loadMore() async {
        guard !isLoadingMore, hasMoreThreads else { return }
        let currentSelection = selection
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.loadMore(for: currentSelection)
            let known = Set(threads.map(\.id))
            threads += page.threads.filter { !known.contains($0.id) }
            if selection == currentSelection {
                hasMoreThreads = page.hasMore
            }
        } catch {
            alert = error.localizedDescription
        }
    }

    private func refreshHasMore() {
        let currentSelection = selection
        Task {
            let more = await service.hasMore(for: currentSelection)
            if selection == currentSelection {
                hasMoreThreads = more
            }
        }
    }

    func archive(_ id: MailThread.ID) {
        file(id, in: .archive, title: "Archived", symbol: Mailbox.archive.symbol, cue: .lift)
    }

    func trash(_ id: MailThread.ID) {
        file(id, in: .trash, title: "Moved to Trash", symbol: Mailbox.trash.symbol, cue: .warning)
    }

    func move(_ id: MailThread.ID, to mailbox: Mailbox) {
        file(id, in: mailbox, title: "Moved to \(mailbox.title)", symbol: mailbox.symbol, cue: .lift)
    }

    /// Files a thread under a label, as Gmail's Move does: it leaves the Inbox, and the label being shown.
    func move(_ id: MailThread.ID, toLabel label: MailLabel.ID) {
        guard let thread = thread(id), let name = self.label(label)?.name else { return }
        var shown: MailLabel.ID?
        if case .label(let open) = selection, open != label, thread.labelIDs.contains(open) {
            shown = open
        }
        let change = ThreadChange.file(under: label, leaving: shown)
        var filed = thread
        change.apply(to: &filed)
        guard filed != thread else { return }
        if !filed.belongs(to: selection, at: now) {
            deselect(id)
        }
        commit(change, to: id, cue: .lift)
        toast = UndoToast(title: "Moved to \(name)", symbol: "tag", previous: [thread])
    }

    func setLabel(_ label: MailLabel.ID, on id: MailThread.ID, isOn: Bool) {
        guard let thread = thread(id), thread.labelIDs.contains(label) != isOn else { return }
        if !isOn, selection == .label(label) {
            deselect(id)
        }
        commit(.setLabel(label, isOn), to: id, cue: .selection)
    }

    func snooze(_ id: MailThread.ID, until option: SnoozeOption) {
        let date = option.date(from: now, calendar: calendar)
        snooze(id, until: date)
    }

    /// Snoozes a thread until an explicit date and time.
    func snooze(_ id: MailThread.ID, until date: Date) {
        guard let thread = thread(id), thread.folder != .trash else { return }
        if !hasSearchQuery && selection == .mailbox(.inbox) {
            deselect(id)
        }
        commit(.snooze(date), to: id, cue: .lift)
        scheduleSnoozeWake()
        toast = UndoToast(title: "Snoozed", symbol: Mailbox.snoozed.symbol, previous: [thread])
    }

    /// Returns a snoozed thread to the Inbox immediately.
    func unsnooze(_ id: MailThread.ID) {
        guard let thread = thread(id), thread.snoozedUntil != nil else { return }
        if !hasSearchQuery && selection == .mailbox(.snoozed) {
            deselect(id)
        }
        commit(.snooze(nil), to: id, cue: .lift)
        scheduleSnoozeWake()
        toast = UndoToast(title: "Returned to Inbox", symbol: Mailbox.inbox.symbol, previous: [thread])
    }

    /// Archives several threads at once, with one toast to undo them all.
    func archive(_ ids: [MailThread.ID]) {
        let moving = ids.compactMap(thread).filter { $0.folder != .archive }
        guard !moving.isEmpty else { return }
        for thread in moving {
            if willLeaveCurrentList(thread.id, after: .move(.archive)) {
                deselect(thread.id)
            }
            commit(.move(.archive), to: thread.id, cue: nil)
        }
        haptic = HapticCue(kind: .lift)
        let title = moving.count == 1 ? "Archived" : "Archived \(moving.count)"
        toast = UndoToast(title: title, symbol: Mailbox.archive.symbol, previous: moving)
    }

    /// Clears per-account preferences kept in defaults when signing out.
    func clearAccountDefaults() {
        unsubscribed = []
        defaults?.removeObject(forKey: Self.unsubscribedKey)
    }

    // MARK: Unsubscribing

    func isUnsubscribed(from sender: Contact) -> Bool {
        unsubscribed.contains(sender.email.lowercased())
    }

    /// The Inbox threads with mail from a sender, newest first.
    func inboxThreads(from sender: Contact) -> [MailThread.ID] {
        let address = sender.email.lowercased()
        let now = self.now
        return threads
            .filter { thread in
                thread.belongs(to: .mailbox(.inbox), at: now)
                    && thread.messages.contains { $0.sender.email.lowercased() == address }
            }
            .sorted { $0.date > $1.date }
            .map(\.id)
    }

    /// Leaves the mailing list a message came from. True once the list has been told;
    /// a page the person must finish themselves is handed to `open`.
    func unsubscribe(from message: Message, open: (URL) -> Void) async -> Bool {
        guard let offer = message.unsubscribe else { return false }
        do {
            switch try await service.unsubscribe(offer) {
            case .done:
                unsubscribed.insert(message.sender.email.lowercased())
                defaults?.set(unsubscribed.sorted(), forKey: Self.unsubscribedKey)
                haptic = HapticCue(kind: .success)
                return true
            case .openPage(let url):
                open(url)
                return false
            }
        } catch {
            alert = error.localizedDescription
            haptic = HapticCue(kind: .warning)
            return false
        }
    }

    /// Reverses the action the toast describes, or cancels a pending Undo Send.
    func undo() {
        if let pendingDraft = pendingSendDraft {
            pendingSendTask?.cancel()
            pendingSendTask = nil
            pendingSendDraft = nil
            toast = nil
            cancelledDraft = pendingDraft
            haptic = HapticCue(kind: .selection)
            return
        }
        guard let toast else { return }
        self.toast = nil
        for previous in toast.previous {
            guard let index = threads.firstIndex(where: { $0.id == previous.id }) else {
                // Thread was removed from local list (for example by Mark as Spam): restore it.
                threads.append(previous)
                Task {
                    do {
                        try await service.markSpam([previous.id], isSpam: false)
                    } catch {
                        threads.removeAll { $0.id == previous.id }
                        alert = error.localizedDescription
                    }
                }
                continue
            }
            let current = threads[index]
            let labels = Set(current.labelIDs).symmetricDifference(previous.labelIDs)
            threads[index] = previous
            var changes: [ThreadChange] = []
            for label in labels.sorted() {
                changes.append(.setLabel(label, previous.labelIDs.contains(label)))
            }
            if current.folder != previous.folder {
                changes.append(.move(previous.folder))
            }
            if current.snoozedUntil != previous.snoozedUntil {
                changes.append(.snooze(previous.snoozedUntil))
            }
            if current.isPinned != previous.isPinned {
                changes.append(.setPinned(previous.isPinned))
            }
            for change in changes {
                report(change, for: previous.id, rollback: current)
            }
        }
        scheduleSnoozeWake()
        if hasSearchQuery {
            refreshSearchResults()
        }
        haptic = HapticCue(kind: .selection)
    }

    func dismissToast(_ id: UndoToast.ID) {
        if toast?.id == id {
            toast = nil
        }
    }

    private func file(_ id: MailThread.ID, in mailbox: Mailbox, title: String, symbol: String, cue: HapticCue.Kind) {
        guard let thread = thread(id), thread.folder != mailbox else { return }
        if willLeaveCurrentList(id, after: .move(mailbox)) {
            deselect(id)
        }
        commit(.move(mailbox), to: id, cue: cue)
        toast = UndoToast(title: title, symbol: symbol, previous: [thread])
    }

    private func willLeaveCurrentList(_ id: MailThread.ID, after change: ThreadChange) -> Bool {
        guard var copy = thread(id) else { return false }
        change.apply(to: &copy)
        if hasSearchQuery {
            return copy.folder == .trash
        }
        return !copy.belongs(to: selection, at: now) || !filter.matches(copy)
    }

    /// Moves the split view's selection to a neighbor before a thread leaves the list.
    private func deselect(_ id: MailThread.ID) {
        guard selectedThreadID == id else { return }
        let visible = orderedVisibleIDs
        guard let index = visible.firstIndex(of: id) else {
            selectedThreadID = nil
            return
        }
        let neighbor = index + 1 < visible.count ? index + 1 : index - 1
        selectedThreadID = visible.indices.contains(neighbor) ? visible[neighbor] : nil
    }

    /// Applies a change locally, then reports it to the service.
    private func commit(_ change: ThreadChange, to id: MailThread.ID, cue: HapticCue.Kind?) {
        guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
        let previous = threads[index]
        change.apply(to: &threads[index])
        if hasSearchQuery {
            refreshSearchResults()
        }
        if let cue {
            haptic = HapticCue(kind: cue)
        }
        report(change, for: id, rollback: previous)
    }

    /// Sends one change to the service, serialized per thread so rapid edits and undos stay in order.
    private func report(_ change: ThreadChange, for id: MailThread.ID, rollback: MailThread?) {
        let generation = (mutationGenerations[id] ?? 0) + 1
        mutationGenerations[id] = generation
        let previousTask = pendingMutations[id]
        let task = Task {
            await previousTask?.value
            do {
                try await service.apply(change, to: [id])
            } catch {
                if let rollback,
                   mutationGenerations[id] == generation,
                   let index = threads.firstIndex(where: { $0.id == id }) {
                    threads[index] = rollback
                    if hasSearchQuery {
                        refreshSearchResults()
                    }
                }
                alert = error.localizedDescription
            }
        }
        pendingMutations[id] = task
    }

    // MARK: Selection

    /// Switches the list to another mailbox or label.
    func show(_ selection: MailboxSelection) {
        guard self.selection != selection else { return }
        self.selection = selection
        filter = .all
        selectedThreadID = nil
        clearSelection()
        endSearch()
        refreshHasMore()
        haptic = HapticCue(kind: .selection)
        Task { await bringIn(selection) }
    }

    /// Asks for a label's or mailbox's older mail the first time it is opened.
    private func bringIn(_ selection: MailboxSelection) async {
        guard await service.watch(selection) else { return }
        if isFetching {
            isFetchQueued = true
        }
        guard phase == .loaded else { return }
        // Shows that mail is on its way, so the mailbox does not read as empty meanwhile.
        syncProgress = syncProgress ?? 0
        if !isFetching {
            await fetch(isQuiet: true)
        }
    }

    /// False while mail is still arriving, when an empty list does not mean an empty mailbox.
    var isSettled: Bool {
        phase == .loaded && syncProgress == nil
    }

    func select(_ id: MailThread.ID?) {
        selectedThreadID = id
        if let id {
            markRead(id)
        }
    }

    /// The threads currently on screen in visual order (pinned first in Inbox).
    private var orderedVisibleIDs: [MailThread.ID] {
        hasSearchQuery ? searchResults.map(\.id) : sections.flatMap(\.threads).map(\.id)
    }

    /// Moves the selection up or down the visible list.
    func selectNeighbor(offset: Int) {
        let ids = orderedVisibleIDs
        guard !ids.isEmpty else { return }
        guard let current = selectedThreadID, let index = ids.firstIndex(of: current) else {
            select(offset > 0 ? ids.first : ids.last)
            return
        }
        let target = min(max(index + offset, 0), ids.count - 1)
        select(ids[target])
    }

    // MARK: Sending

    /// Queues a draft to send after a brief Undo Send window. Tapping Undo cancels delivery
    /// and restores the draft in `cancelledDraft` so the composer can reopen it.
    func scheduleSend(_ draft: Draft, delay: Duration = .seconds(5)) {
        // Flush any previously queued draft immediately so nothing is lost.
        if let previous = pendingSendDraft {
            pendingSendTask?.cancel()
            pendingSendDraft = nil
            Task { _ = await send(previous) }
        }
        pendingSendDraft = draft
        let sendToast = UndoToast(title: "Sending…", symbol: "paperplane", previous: [])
        toast = sendToast
        haptic = HapticCue(kind: .lift)
        pendingSendTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, let pending = self.pendingSendDraft else { return }
            self.pendingSendDraft = nil
            self.pendingSendTask = nil
            self.dismissToast(sendToast.id)
            _ = await self.send(pending)
        }
    }

    /// Sends a draft. A reply joins its thread and anything else starts a thread in Sent.
    func send(_ draft: Draft) async -> Bool {
        let message = Message(
            sender: account,
            to: draft.to,
            cc: draft.cc,
            date: now,
            body: draft.body,
            quoted: draft.quoted,
            attachments: draft.attachments
        )
        let sentThreadID: MailThread.ID?
        do {
            sentThreadID = try await service.sendDraft(draft)
        } catch {
            alert = error.localizedDescription
            haptic = HapticCue(kind: .warning)
            return false
        }

        if let sourceID = draft.sourceDraftThreadID {
            if selectedThreadID == sourceID {
                deselect(sourceID)
            }
            threads.removeAll { $0.id == sourceID }
        }
        if let id = draft.threadID, let index = threads.firstIndex(where: { $0.id == id }) {
            threads[index].messages.append(message)
            threads[index].hasSentMessages = true
        } else {
            let newID = sentThreadID ?? UUID().uuidString
            threads.append(MailThread(id: newID, subject: draft.subject, messages: [message], folder: .sent, hasSentMessages: true))
        }
        if hasSearchQuery {
            refreshSearchResults()
        }
        haptic = HapticCue(kind: .success)
        return true
    }

    /// Files a draft in Drafts to finish later, updating an existing draft locally and syncing it to the service.
    func saveDraft(_ draft: Draft) {
        let message = Message(
            sender: account, to: draft.to, cc: draft.cc, date: now,
            body: draft.body, quoted: draft.quoted, attachments: draft.attachments
        )
        let localID: MailThread.ID
        if let sourceID = draft.sourceDraftThreadID,
           let index = threads.firstIndex(where: { $0.id == sourceID && $0.folder == .drafts }) {
            threads[index].subject = draft.subject
            threads[index].messages = [message]
            localID = sourceID
        } else {
            let newThread = MailThread(subject: draft.subject, messages: [message], folder: .drafts)
            threads.append(newThread)
            localID = newThread.id
        }
        Task {
            do {
                if let synced = try await service.saveDraft(draft) {
                    if let index = threads.firstIndex(where: { $0.id == localID }) {
                        threads[index] = synced
                    } else if !threads.contains(where: { $0.id == synced.id }) {
                        threads.append(synced)
                    }
                }
            } catch {
                alert = error.localizedDescription
            }
        }
    }

    // MARK: Search

    func recordSearch(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        recentSearches.insert(query, at: 0)
        if recentSearches.count > 6 {
            recentSearches = Array(recentSearches.prefix(6))
        }
        defaults?.set(recentSearches, forKey: Self.recentSearchesKey)
    }

    func clearRecentSearches() {
        recentSearches = []
        defaults?.removeObject(forKey: Self.recentSearchesKey)
    }

    func setSearchFilter(_ filter: InboxFilter) {
        searchFilter = filter
        refreshSearchResults()
    }

    /// Shows matches from loaded mail at once, then merges in what the service finds.
    func search() {
        searchTask?.cancel()
        remoteSearchIDs = []
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        refreshSearchResults()
        guard !query.isEmpty else {
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let remote = (try? await service.search(query)) ?? []
            guard !Task.isCancelled else { return }

            // Older mail the service found joins the mailbox, so a result can be opened and filed.
            let known = Set(threads.map(\.id))
            threads += remote.filter { !known.contains($0.id) }
            remoteSearchIDs = Set(remote.map(\.id))
            refreshSearchResults()
            isSearching = false
        }
    }

    func endSearch() {
        searchTask?.cancel()
        searchQuery = ""
        searchFilter = .all
        remoteSearchIDs = []
        searchResults = []
        isSearching = false
    }

    /// Keeps `searchResults` in step with local edits, active search filter, and remote matches.
    private func refreshSearchResults() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            if searchFilter != .all {
                searchResults = threads
                    .filter { $0.folder != .trash && searchFilter.matches($0) }
                    .sorted { $0.date > $1.date }
                    .map { SearchResult(thread: $0, excerpt: $0.preview) }
            } else {
                searchResults = []
            }
            return
        }
        var results = MailSearch.results(for: query, in: threads)
        let localIDs = Set(results.map(\.id))
        // Keep remote service matches even when Gmail matched outside the local snippet/subject.
        let remoteExtras = threads
            .filter { remoteSearchIDs.contains($0.id) && !localIDs.contains($0.id) && $0.folder != .trash }
            .map { SearchResult(thread: $0, excerpt: $0.preview) }
        results += remoteExtras
        if searchFilter != .all {
            results = results.filter { searchFilter.matches($0.thread) }
        }
        results.sort { $0.thread.date > $1.thread.date }
        searchResults = results
    }
}
