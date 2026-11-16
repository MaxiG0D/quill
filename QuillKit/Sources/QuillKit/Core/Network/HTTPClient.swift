import Foundation

/// The network as the app sees it, so tests can stand in for it.
protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
