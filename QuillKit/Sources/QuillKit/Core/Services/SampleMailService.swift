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
    }

    func search(_ query: String) async throws -> [MailThread] {
        try await Task.sleep(for: latency)
        return MailSearch.results(for: query, in: data.threads).map(\.thread)
    }
}
