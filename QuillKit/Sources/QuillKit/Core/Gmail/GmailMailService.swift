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

    /// How many threads are listed from the Inbox, and from the newest mail anywhere.
    private static let recentLimit = 100
    /// How many threads are listed from Starred, Drafts and Trash.
    private static let sideLimit = 25
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

    func snapshot() async throws -> MailSnapshot {
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
        let account = Contact(name: user.name ?? "", email: user.email.lowercased(), tone: .teal)
        let mapper = GmailMapper(account: account, labels: GmailMapper.labels(from: try await gmailLabels))

        var seen = Set<String>()
        // In the order they are fetched when Gmail's allowance cannot cover them all at once.
        let references = try await (inbox + starred + drafts + recent + trashed).filter { seen.insert($0.id).inserted }

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
        var snapshot = next.snapshot
        snapshot.isComplete = isComplete
        return snapshot
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

    /// Removes everything kept on the device for this account.
    func erase() {
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
