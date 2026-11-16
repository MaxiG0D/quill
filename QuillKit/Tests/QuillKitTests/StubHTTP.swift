import Foundation
@testable import QuillKit

/// Answers requests from a table of canned JSON, and remembers what was asked.
actor StubHTTP: HTTPClient {
    struct Reply: Sendable {
        var status = 200
        var json = "{}"
    }

    private var replies: [String: Reply] = [:]
    private(set) var requests: [URLRequest] = []

    /// Answers any request whose URL contains `fragment`. The longest matching fragment wins.
    func reply(to fragment: String, status: Int = 200, json: String) {
        replies[fragment] = Reply(status: status, json: json)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let address = request.url?.absoluteString ?? ""
        let match = replies.keys.filter { address.contains($0) }.max { $0.count < $1.count }
        let reply = match.flatMap { replies[$0] } ?? Reply(status: 404, json: #"{"error":{"message":"No stub for \#(address)"}}"#)
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(reply.json.utf8), response)
    }

    /// The paths requested so far, in order, with the method in front.
    func log() -> [String] {
        requests.map { "\($0.httpMethod ?? "GET") \($0.url?.path() ?? "")" }
    }

    /// The label change a request carried.
    func labelChange(at index: Int) -> [String: [String]] {
        let data = requests[index].httpBody ?? Data()
        return (try? JSONDecoder().decode([String: [String]].self, from: data)) ?? [:]
    }

    func body(at index: Int) -> String {
        String(decoding: requests[index].httpBody ?? Data(), as: UTF8.self)
    }
}
