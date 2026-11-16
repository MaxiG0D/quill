@testable import QuillKit

actor MemoryTokenStore: TokenStore {
    private(set) var token: OAuthToken?

    init(_ token: OAuthToken? = nil) {
        self.token = token
    }

    func load() async throws -> OAuthToken? { token }
    func save(_ token: OAuthToken) async throws { self.token = token }
    func clear() async throws { token = nil }
}
