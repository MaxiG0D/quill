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

    var selection: MailboxSelection = .mailbox(.inbox)
    var filter: InboxFilter = .all
    /// The open thread in the three-column layout.
    var selectedThreadID: MailThread.ID?

    var searchQuery = ""
    private(set) var searchResults: [SearchResult] = []
    private(set) var isSearching = false

    private(set) var toast: UndoToast?
    private(set) var haptic: HapticCue?
    /// A failure the person should hear about.
    var alert: String?

    let calendar: Calendar
    private let service: any MailService
    private let clock: @Sendable () -> Date
    private var searchTask: Task<Void, Never>?
    private var isFetching = false
    private var continuation: Task<Void, Never>?
    private static let log = Logger(subsystem: "com.maxig0d.quill", category: "mail")

    init(
        service: any MailService,
        calendar: Calendar = .current,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.service = service
        self.calendar = calendar
        self.clock = clock
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
            clock: clock
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
        let now = self.now
        return threads
            .filter { $0.belongs(to: selection, at: now) && filter.matches($0) }
            .sorted { $0.date > $1.date }
    }

    var sections: [ThreadSection] {
        ThreadSection.sections(for: visibleThreads, now: now, calendar: calendar, pinsFirst: isInbox)
    }

    /// The number shown beside the title: unread threads in the current mailbox.
    var unreadCount: Int {
        let now = self.now
        return threads.count { $0.belongs(to: selection, at: now) && $0.isUnread }
    }

    /// The number shown beside a mailbox or label, or nil when there is nothing to show.
    func badge(for selection: MailboxSelection) -> Int? {
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

    func labels(for thread: MailThread) -> [MailLabel] {
        thread.labelIDs.compactMap(label)
    }

    /// Everyone who appears in the mailbox, for recipient suggestions.
    var knownContacts: [Contact] {
        var seen = Set<Contact.ID>()
        return threads
            .flatMap { $0.messages.flatMap { [$0.sender] + $0.to + $0.cc } }
            .filter { $0 != account && seen.insert($0.id).inserted }
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

    private func fetch(isQuiet: Bool) async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            let snapshot = try await service.snapshot()
            adopt(snapshot)
            if !snapshot.isComplete {
                continueLoading()
            }
        } catch {
            Self.log.error("Mail could not be loaded: \(String(describing: error), privacy: .public)")
            if threads.isEmpty && phase != .loaded {
                phase = .failed(Self.describe(error))
            } else if !isQuiet {
                alert = Self.describe(error)
            }
        }
    }

    /// Fetches the next part of a mailbox that is arriving in passes, once the service's
    /// allowance has had time to refill.
    private func continueLoading() {
        continuation?.cancel()
        continuation = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
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

    /// Marks a thread read when it is opened.
    func markRead(_ id: MailThread.ID) {
        guard thread(id)?.isUnread == true else { return }
        commit(.setUnread(false), to: id, cue: nil)
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

    func snooze(_ id: MailThread.ID, until option: SnoozeOption) {
        guard let thread = thread(id) else { return }
        let date = option.date(from: now, calendar: calendar)
        deselect(id)
        commit(.snooze(date), to: id, cue: .lift)
        toast = UndoToast(title: "Snoozed", symbol: Mailbox.snoozed.symbol, previous: [thread])
    }

    /// Reverses the action the toast describes.
    func undo() {
        guard let toast else { return }
        self.toast = nil
        for previous in toast.previous {
            guard let index = threads.firstIndex(where: { $0.id == previous.id }) else { continue }
            threads[index] = previous
            report(.move(previous.folder), for: previous.id, rollback: nil)
            report(.snooze(previous.snoozedUntil), for: previous.id, rollback: nil)
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
        deselect(id)
        commit(.move(mailbox), to: id, cue: cue)
        toast = UndoToast(title: title, symbol: symbol, previous: [thread])
    }

    /// Moves the split view's selection to a neighbor before a thread leaves the list.
    private func deselect(_ id: MailThread.ID) {
        guard selectedThreadID == id else { return }
        let visible = visibleThreads
        guard let index = visible.firstIndex(where: { $0.id == id }) else {
            selectedThreadID = nil
            return
        }
        let neighbor = index + 1 < visible.count ? index + 1 : index - 1
        selectedThreadID = visible.indices.contains(neighbor) ? visible[neighbor].id : nil
    }

    /// Applies a change locally, then reports it to the service.
    private func commit(_ change: ThreadChange, to id: MailThread.ID, cue: HapticCue.Kind?) {
        guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
        let previous = threads[index]
        change.apply(to: &threads[index])
        if let cue {
            haptic = HapticCue(kind: cue)
        }
        report(change, for: id, rollback: previous)
    }

    private func report(_ change: ThreadChange, for id: MailThread.ID, rollback: MailThread?) {
        Task {
            do {
                try await service.apply(change, to: [id])
            } catch {
                if let rollback, let index = threads.firstIndex(where: { $0.id == id }) {
                    threads[index] = rollback
                }
                alert = error.localizedDescription
            }
        }
    }

    // MARK: Selection

    /// Switches the list to another mailbox or label.
    func show(_ selection: MailboxSelection) {
        guard self.selection != selection else { return }
        self.selection = selection
        selectedThreadID = nil
        endSearch()
        haptic = HapticCue(kind: .selection)
    }

    func select(_ id: MailThread.ID?) {
        selectedThreadID = id
        if let id {
            markRead(id)
        }
    }

    /// Moves the selection up or down the visible list.
    func selectNeighbor(offset: Int) {
        let ids = searchQuery.isEmpty ? visibleThreads.map(\.id) : searchResults.map(\.id)
        guard !ids.isEmpty else { return }
        guard let current = selectedThreadID, let index = ids.firstIndex(of: current) else {
            select(offset > 0 ? ids.first : ids.last)
            return
        }
        let target = min(max(index + offset, 0), ids.count - 1)
        select(ids[target])
    }

    // MARK: Sending

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
        do {
            try await service.send(draft)
        } catch {
            alert = error.localizedDescription
            haptic = HapticCue(kind: .warning)
            return false
        }

        if let id = draft.threadID, let index = threads.firstIndex(where: { $0.id == id }) {
            threads[index].messages.append(message)
        } else {
            threads.append(MailThread(subject: draft.subject, messages: [message], folder: .sent))
        }
        haptic = HapticCue(kind: .success)
        return true
    }

    /// Files a draft in Drafts to finish later.
    func saveDraft(_ draft: Draft) {
        let message = Message(
            sender: account, to: draft.to, cc: draft.cc, date: now,
            body: draft.body, quoted: draft.quoted, attachments: draft.attachments
        )
        threads.append(MailThread(subject: draft.subject, messages: [message], folder: .drafts))
    }

    // MARK: Search

    /// Shows matches from loaded mail at once, then merges in what the service finds.
    func search() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchResults = MailSearch.results(for: query, in: threads)
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
            searchResults = MailSearch.results(for: query, in: threads)
            isSearching = false
        }
    }

    func endSearch() {
        searchTask?.cancel()
        searchQuery = ""
        searchResults = []
        isSearching = false
    }
}
