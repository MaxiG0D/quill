import Foundation

/// Mail from the signed-in Gmail account.
///
/// A refresh lists the newest threads and fetches only those that changed since the
/// archive last saw them, so opening the app costs a few small calls on most launches.
actor GmailMailService: MailService {
    private let api: GmailAPI
    private let file: MailArchiveFile?
    private var archive: MailArchive?
    private var hasReadFile = false
    /// How much of the listed mailbox was up to date after the last refresh.
    private var progress = 0.0
    /// Gmail labels opened on this device, most recent first. Nil until read from the archive.
    private var watched: [String]?

    /// How many threads are listed from the Inbox, and from the newest mail anywhere.
    private static let recentLimit = 100
    /// How many threads are listed from Starred, Drafts and Trash.
    private static let sideLimit = 25
    /// How many threads are listed from each label the person has opened.
    private static let labelLimit = 50
    /// How many opened labels are kept up to date. The least recently opened drop off.
    private static let watchLimit = 20
    private static let searchLimit = 25
    /// How many threads one refresh fetches. A full thread costs up to 60 of the 6,000
    /// quota units Gmail allows an account each minute, so this leaves room to spare.
    private static let passLimit = 40
    private static let concurrentFetches = 4

    init(api: GmailAPI, file: MailArchiveFile? = .standard) {
        self.api = api
        self.file = file
    }

    func cachedSnapshot() async -> MailSnapshot? {
        stored()?.snapshot
    }

    /// The mailbox, brought up to date as far as Gmail's allowance goes. When the allowance
    /// is spent before anything new arrives, the mailbox on the device is returned as
    /// incomplete, so the caller comes back later instead of failing.
    func snapshot() async throws -> MailSnapshot {
        do {
            return try await refreshed()
        } catch GmailError.rateLimited {
            guard var kept = stored()?.snapshot else { throw GmailError.rateLimited }
            kept.isComplete = false
            kept.progress = progress
            return kept
        }
    }

    private func refreshed() async throws -> MailSnapshot {
        let api = api
        async let info = api.userInfo()
        async let gmailLabels = api.labels()
        // The Inbox, Starred and Drafts are asked for by name, because mail can sit in them
        // long after it has dropped out of the newest hundred threads.
        async let inbox = api.threadReferences(labelIDs: ["INBOX"], limit: Self.recentLimit)
        async let starred = api.threadReferences(labelIDs: ["STARRED"], limit: Self.sideLimit)
        async let drafts = api.threadReferences(labelIDs: ["DRAFT"], limit: Self.sideLimit)
        async let recent = api.threadReferences(limit: Self.recentLimit)
        async let trashed = api.threadReferences(labelIDs: ["TRASH"], limit: Self.sideLimit)

        let user = try await info
        let account = Contact(name: user.name ?? "", email: user.email.lowercased(), tone: .teal, photoURL: user.photoURL)
        let mapper = GmailMapper(account: account, labels: GmailMapper.labels(from: try await gmailLabels))

        // Mail under a label can be far older than the newest hundred threads, so every
        // label the person has opened is asked for by name. Gmail rejects a label it no
        // longer has, so those that were deleted are dropped first.
        let existing = Set(mapper.labels.map(\.id)).union(Self.watchableSystemLabels)
        let watched = watchedLabels().filter(existing.contains)
        let labelled = try await labelReferences(watched)

        var seen = Set<String>()
        // In the order they are fetched when Gmail's allowance cannot cover them all at once.
        let references = try await (inbox + labelled + starred + drafts + recent + trashed).filter { seen.insert($0.id).inserted }

        // Another account's archive is of no use here.
        var old = stored()
        if old?.account.email != account.email {
            old = nil
        }
        let changed = references.filter { reference in
            old?.thread(reference.id) == nil || old?.historyIDs[reference.id] != reference.historyId
        }
        // Gmail meters each account by the minute, so a big mailbox arrives over several
        // passes: the newest changed threads now, the rest on the refreshes that follow.
        let pass = try await threads(Array(changed.prefix(Self.passLimit)).map(\.id), mapper: mapper)
        let fetched = pass.threads
        if fetched.isEmpty, pass.wasCutShort, old == nil {
            throw GmailError.rateLimited
        }

        var next = MailArchive(account: account, labels: mapper.labels)
        // Read again, because a label may have been opened while Gmail was answering.
        let stillWatched = watchedLabels().filter(existing.contains)
        next.watched = stillWatched
        self.watched = stillWatched
        let listed = Set(references.map(\.id))
        next.pinned = (old?.pinned ?? []).intersection(listed)
        next.snoozed = (old?.snoozed ?? [:]).filter { listed.contains($0.key) }
        var isComplete = true
        for reference in references {
            if let mapped = fetched[reference.id] {
                next.threads.append(next.decorated(mapped.thread))
                next.anchors[reference.id] = mapped.anchor
                next.historyIDs[reference.id] = reference.historyId
            } else if let thread = old?.thread(reference.id) {
                // Unchanged, or changed and still waiting its turn: the copy on the device stands,
                // under the history ID it was fetched with so a stale one is fetched next time.
                next.threads.append(thread)
                next.anchors[reference.id] = old?.anchors[reference.id]
                next.historyIDs[reference.id] = old?.historyIDs[reference.id]
                isComplete = isComplete && old?.historyIDs[reference.id] == reference.historyId
            } else if !pass.missing.contains(reference.id) {
                // New to the device and not fetched yet.
                isComplete = false
            }
        }
        keep(next)
        let current = references.count { next.historyIDs[$0.id] == $0.historyId || pass.missing.contains($0.id) }
        progress = references.isEmpty ? 1 : Double(current) / Double(references.count)
        var snapshot = next.snapshot
        snapshot.isComplete = isComplete
        snapshot.progress = progress
        return snapshot
    }

    /// One thread's own call, for mail a notification has just announced: a single request
    /// instead of the listings and label lookups a full refresh makes first.
    func fetchThread(_ id: MailThread.ID) async throws -> MailSnapshot? {
        guard var next = stored() else { return nil }
        let mapper = GmailMapper(account: next.account, labels: next.labels)
        let resource: GmailResource.Thread
        do {
            resource = try await api.thread(id)
        } catch GmailError.status(404, _) {
            return nil
        }
        // Read again: a refresh or a change may have written the archive while Gmail answered.
        next = stored() ?? next
        guard let mapped = mapper.thread(from: resource) else { return nil }
        next.threads.removeAll { $0.id == id }
        next.threads.insert(next.decorated(mapped.thread), at: 0)
        next.anchors[id] = mapped.anchor
        next.historyIDs[id] = resource.historyId
        keep(next)
        return next.snapshot
    }

    func apply(_ change: ThreadChange, to ids: [MailThread.ID]) async throws {
        for id in ids {
            let known = stored()?.thread(id)
            let latest = stored()?.anchors[id]?.latestMessageID
            switch change {
            case .move(let mailbox):
                try await move(id, from: known?.folder, to: mailbox)
            case .setStarred(let isStarred):
                try await mark(id, latest: latest, with: "STARRED", isOn: isStarred)
            case .setUnread(let isUnread):
                try await mark(id, latest: latest, with: "UNREAD", isOn: isUnread)
            case .setPinned(let isPinned):
                update { archive in
                    if isPinned {
                        archive.pinned.insert(id)
                    } else {
                        archive.pinned.remove(id)
                    }
                }
            case .snooze(let date):
                update { $0.snoozed[id] = date }
            case .setLabel(let label, let isOn):
                try await api.modifyThread(id, adding: isOn ? [label] : [], removing: isOn ? [] : [label])
            case .file(let label, let old):
                if known?.folder == .trash {
                    try await api.untrashThread(id)
                }
                try await api.modifyThread(id, adding: [label], removing: ["INBOX"] + [old].compactMap { $0 })
            }
            // Gmail gives a changed thread a new history ID, so the next refresh fetches it again.
            update { archive in
                guard let index = archive.threads.firstIndex(where: { $0.id == id }) else { return }
                change.apply(to: &archive.threads[index])
            }
        }
    }

    func send(_ draft: Draft) async throws {
        guard draft.attachments.isEmpty else {
            throw GmailError.attachmentsUnsupported
        }
        let account: Contact
        if let known = stored()?.account {
            account = known
        } else {
            let user = try await api.userInfo()
            account = Contact(name: user.name ?? "", email: user.email.lowercased())
        }
        let anchor = draft.threadID.flatMap { stored()?.anchors[$0] }
        let raw = OutgoingMail.data(for: draft, from: account, replyingTo: anchor)
        try await api.send(raw: raw, threadID: draft.threadID)
    }

    func postOneClickUnsubscribe(to url: URL) async throws {
        try await api.postOneClickUnsubscribe(to: url)
    }

    func search(_ query: String) async throws -> [MailThread] {
        let references = try await api.threadReferences(query: query, limit: Self.searchLimit)
        let known = stored()
        let mapper = GmailMapper(
            account: known?.account ?? Contact(name: "", email: ""),
            labels: known?.labels ?? []
        )
        let missing = references.map(\.id).filter { known?.thread($0) == nil }
        let fetched = try await threads(missing, mapper: mapper).threads
        return references.compactMap { reference in
            known?.thread(reference.id) ?? fetched[reference.id]?.thread
        }
    }

    func watch(_ selection: MailboxSelection) async -> Bool {
        guard let label = Self.gmailLabel(for: selection) else { return false }
        var labels = watchedLabels()
        guard labels.first != label else { return false }
        let isNew = !labels.contains(label)
        labels.removeAll { $0 == label }
        labels.insert(label, at: 0)
        let kept = Array(labels.prefix(Self.watchLimit))
        watched = kept
        update { $0.watched = kept }
        return isNew
    }

    /// Removes everything kept on the device for this account.
    func erase() {
        watched = []
        archive = nil
        hasReadFile = true
        file?.erase()
    }

    // MARK: Gmail

    private func move(_ id: String, from current: Mailbox?, to mailbox: Mailbox) async throws {
        if mailbox == .trash {
            try await api.trashThread(id)
            return
        }
        if current == .trash {
            try await api.untrashThread(id)
        }
        switch mailbox {
        case .inbox:
            try await api.modifyThread(id, adding: ["INBOX"])
        case .archive:
            try await api.modifyThread(id, removing: ["INBOX"])
        case .sent, .drafts, .starred, .snoozed, .trash:
            // Gmail files these itself. Going back to one, as Undo does, only needs the thread out of the Trash.
            break
        }
    }

    /// Sets a flag on the latest message, as Gmail does, or clears it from the whole thread.
    private func mark(_ id: String, latest: String?, with label: String, isOn: Bool) async throws {
        if !isOn {
            try await api.modifyThread(id, removing: [label])
        } else if let latest {
            try await api.modifyMessage(latest, adding: [label])
        } else {
            try await api.modifyThread(id, adding: [label])
        }
    }

    /// Mailboxes that Gmail keeps as a label and that reach further back than the newest mail.
    private static let watchableSystemLabels: Set<String> = ["SENT"]

    /// The Gmail label whose mail a selection shows, when it has to be asked for by name.
    /// The other mailboxes are already listed on every refresh.
    private static func gmailLabel(for selection: MailboxSelection) -> String? {
        switch selection {
        case .label(let id): id
        case .mailbox(.sent): "SENT"
        case .mailbox: nil
        }
    }

    private func watchedLabels() -> [String] {
        if let watched { return watched }
        let kept = stored()?.watched ?? []
        watched = kept
        return kept
    }

    /// The newest threads under each label, in the order the labels are given.
    private func labelReferences(_ labels: [String]) async throws -> [GmailResource.ThreadReference] {
        let api = api
        return try await withThrowingTaskGroup(of: (Int, [GmailResource.ThreadReference]).self) { group in
            for (index, label) in labels.enumerated() {
                group.addTask {
                    (index, try await api.threadReferences(labelIDs: [label], limit: Self.labelLimit))
                }
            }
            var lists = [[GmailResource.ThreadReference]](repeating: [], count: labels.count)
            for try await (index, list) in group {
                lists[index] = list
            }
            return lists.flatMap { $0 }
        }
    }

    private struct Pass {
        var threads: [String: MappedThread] = [:]
        /// Threads Gmail no longer has.
        var missing: Set<String> = []
        /// True when Gmail's allowance ran out before every thread was fetched.
        var wasCutShort = false
    }

    private enum Fetched: Sendable {
        case thread(MappedThread)
        case missing(String)
        case skipped
        case rateLimited
    }

    /// Fetches threads a few at a time, in the order given. When Gmail's allowance runs
    /// out, the fetch stops and returns what it has.
    private func threads(_ ids: [String], mapper: GmailMapper) async throws -> Pass {
        let api = api
        return try await withThrowingTaskGroup(of: Fetched.self) { group in
            var pass = Pass()
            func record(_ result: Fetched) {
                switch result {
                case .thread(let mapped): pass.threads[mapped.thread.id] = mapped
                case .missing(let id): pass.missing.insert(id)
                case .skipped: break
                case .rateLimited: pass.wasCutShort = true
                }
            }

            var running = 0
            for id in ids where !pass.wasCutShort {
                if running == Self.concurrentFetches, let result = try await group.next() {
                    running -= 1
                    record(result)
                    if pass.wasCutShort { break }
                }
                group.addTask {
                    do {
                        let resource = try await api.thread(id)
                        return mapper.thread(from: resource).map(Fetched.thread) ?? .skipped
                    } catch GmailError.status(404, _) {
                        return .missing(id)
                    } catch GmailError.rateLimited {
                        return .rateLimited
                    }
                }
                running += 1
            }
            for try await result in group {
                record(result)
            }
            return pass
        }
    }

    // MARK: Archive

    private func stored() -> MailArchive? {
        if !hasReadFile {
            archive = file?.load()
            hasReadFile = true
        }
        return archive
    }

    private func keep(_ next: MailArchive) {
        archive = next
        hasReadFile = true
        try? file?.save(next)
    }

    private func update(_ change: (inout MailArchive) -> Void) {
        guard var next = stored() else { return }
        change(&next)
        keep(next)
    }
}
