/// Where the signed-in account's token is kept between launches.
protocol TokenStore: Sendable {
    func load() async throws -> OAuthToken?
    func save(_ token: OAuthToken) async throws
    func clear() async throws
}
