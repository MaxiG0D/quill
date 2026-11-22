import Foundation

/// An in-memory mailbox filled with the content from the design mockups.
/// It stands in for a real provider until Gmail sync is connected.
actor SampleMailService: MailService {
    private var data: MailSnapshot
    private let latency: Duration

    init(snapshot: MailSnapshot = SampleData.snapshot(now: .now), latency: Duration = .milliseconds(450)) {
        self.data = snapshot
        self.latency = latency
    }

    func snapshot() async throws -> MailSnapshot {
        try await Task.sleep(for: latency)
        return data
    }

    func apply(_ change: ThreadChange, to ids: [MailThread.ID]) async throws {
        for index in data.threads.indices where ids.contains(data.threads[index].id) {
            change.apply(to: &data.threads[index])
        }
    }

    func send(_ draft: Draft) async throws {
        try await Task.sleep(for: latency)
        let message = Message(
            sender: data.account,
            to: draft.to,
            cc: draft.cc,
            date: .now,
            body: draft.body,
            quoted: draft.quoted,
            attachments: draft.attachments
        )
        if let source = draft.sourceDraftThreadID {
            data.threads.removeAll { $0.id == source }
        }
        if let id = draft.threadID, let index = data.threads.firstIndex(where: { $0.id == id }) {
            data.threads[index].messages.append(message)
            data.threads[index].hasSentMessages = true
        } else {
            data.threads.append(MailThread(subject: draft.subject, messages: [message], folder: .sent, hasSentMessages: true))
        }
    }

    func saveDraft(_ draft: Draft) async throws -> MailThread? {
        let message = Message(
            sender: data.account, to: draft.to, cc: draft.cc, date: .now,
            body: draft.body, quoted: draft.quoted, attachments: draft.attachments
        )
        if let source = draft.sourceDraftThreadID,
           let index = data.threads.firstIndex(where: { $0.id == source && $0.folder == .drafts }) {
            data.threads[index].subject = draft.subject
            data.threads[index].messages = [message]
            return data.threads[index]
        }
        let thread = MailThread(subject: draft.subject, messages: [message], folder: .drafts)
        data.threads.append(thread)
        return thread
    }

    func deletePermanently(_ ids: [MailThread.ID]) async throws {
        let removed = Set(ids)
        data.threads.removeAll { removed.contains($0.id) }
    }

    func markSpam(_ ids: [MailThread.ID], isSpam: Bool) async throws {
        if isSpam {
            let removed = Set(ids)
            data.threads.removeAll { removed.contains($0.id) }
        }
    }

    func createLabel(name: String) async throws -> MailLabel {
        let label = MailLabel(id: UUID().uuidString, name: name, tone: .stable(for: name))
        data.labels.append(label)
        data.labels.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return label
    }

    func renameLabel(_ id: MailLabel.ID, to name: String) async throws -> MailLabel {
        let label = MailLabel(id: id, name: name, tone: .stable(for: name))
        if let index = data.labels.firstIndex(where: { $0.id == id }) {
            data.labels[index] = label
        }
        data.labels.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return label
    }

    func deleteLabel(_ id: MailLabel.ID) async throws {
        data.labels.removeAll { $0.id == id }
        for index in data.threads.indices {
            data.threads[index].labelIDs.removeAll { $0 == id }
        }
    }

    func search(_ query: String) async throws -> [MailThread] {
        try await Task.sleep(for: latency)
        return MailSearch.results(for: query, in: data.threads).map(\.thread)
    }
}
