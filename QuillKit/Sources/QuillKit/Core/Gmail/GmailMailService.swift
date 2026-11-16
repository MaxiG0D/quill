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

    /// How many of the newest threads a refresh keeps up to date.
    private static let recentLimit = 100
    private static let trashLimit = 25
    private static let searchLimit = 25
    /// Gmail allows each account a few dozen thread fetches a second.
    private static let concurrentFetches = 6

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
        async let recent = api.threadReferences(limit: Self.recentLimit)
        async let trashed = api.threadReferences(labelIDs: ["TRASH"], limit: Self.trashLimit)

        let user = try await info
        let account = Contact(name: user.name ?? "", email: user.email.lowercased(), tone: .teal)
        let mapper = GmailMapper(account: account, labels: GmailMapper.labels(from: try await gmailLabels))

        var seen = Set<String>()
        let references = try await (recent + trashed).filter { seen.insert($0.id).inserted }

        // Another account's archive is of no use here.
        var old = stored()
        if old?.account.email != account.email {
            old = nil
        }
        let changed = references.filter { reference in
            old?.thread(reference.id) == nil || old?.historyIDs[reference.id] != reference.historyId
        }
        let fetched = try await threads(changed.map(\.id), mapper: mapper)

        var next = MailArchive(account: account, labels: mapper.labels)
        let listed = Set(references.map(\.id))
        next.pinned = (old?.pinned ?? []).intersection(listed)
        next.snoozed = (old?.snoozed ?? [:]).filter { listed.contains($0.key) }
        for reference in references {
            if let mapped = fetched[reference.id] {
                next.threads.append(next.decorated(mapped.thread))
                next.anchors[reference.id] = mapped.anchor
            } else if let thread = old?.thread(reference.id), !changed.contains(reference) {
                next.threads.append(thread)
                next.anchors[reference.id] = old?.anchors[reference.id]
            } else {
                // Changed, but gone by the time it was fetched.
                continue
            }
            next.historyIDs[reference.id] = reference.historyId
        }
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
        let fetched = try await threads(missing, mapper: mapper)
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

    /// Fetches threads a few at a time. A thread deleted in the meantime is left out.
    private func threads(_ ids: [String], mapper: GmailMapper) async throws -> [String: MappedThread] {
        let api = api
        return try await withThrowingTaskGroup(of: MappedThread?.self) { group in
            var results: [String: MappedThread] = [:]
            var running = 0
            for id in ids {
                if running == Self.concurrentFetches, let mapped = try await group.next() {
                    running -= 1
                    if let mapped {
                        results[mapped.thread.id] = mapped
                    }
                }
                group.addTask {
                    do {
                        let resource = try await api.thread(id)
                        return mapper.thread(from: resource)
                    } catch GmailError.status(404, _) {
                        return nil
                    }
                }
                running += 1
            }
            for try await mapped in group {
                if let mapped {
                    results[mapped.thread.id] = mapped
                }
            }
            return results
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
