import Foundation
import Testing
@testable import QuillKit

struct PushRelayTests {
    private static func relay(_ http: StubHTTP, address: String = "https://relay.example") -> PushRelay? {
        let auth = GoogleAuth(client: GmailFixture.client, http: http, tokens: MemoryTokenStore(GmailFixture.token()))
        return PushRelay(address: address, auth: auth, http: http)
    }

    @Test func anUnsetOrInsecureAddressLeavesPushOff() {
        #expect(Self.relay(StubHTTP(), address: "") == nil)
        #expect(Self.relay(StubHTTP(), address: "http://relay.example") == nil)
        #expect(Self.relay(StubHTTP(), address: " https://relay.example/ ") != nil)
    }

    @Test func thePushEnvironmentComesFromTheSigningProfile() {
        let profile = "junk<key>aps-environment</key>\n\t<string>development</string><key>get-task-allow</key><true/>"
        #expect(PushRelay.environment(inProfile: profile) == "development")
        #expect(PushRelay.environment(inProfile: "<key>get-task-allow</key><true/>") == nil)
    }

    @Test func registeringSendsTheDeviceAndTheAccountsTokens() async throws {
        let http = StubHTTP()
        await http.reply(to: "/devices", status: 204, json: "")
        try await #require(Self.relay(http)).register("abc123")

        let request = try #require(await http.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://relay.example/devices")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
        let json = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any] ?? [:]
        #expect(json["allInbox"] as? Bool == false)
        let body = json.compactMapValues { $0 as? String }
        #expect(body["deviceToken"] == "abc123")
        #expect(body["refreshToken"] == "refresh")
        #expect(body["environment"] == "development" || body["environment"] == "production")
        #expect(body["platform"] == "ios" || body["platform"] == "macos")
    }

    @Test func unregisteringNamesOnlyTheDevice() async throws {
        let http = StubHTTP()
        await http.reply(to: "/devices", status: 204, json: "")
        try await #require(Self.relay(http)).unregister("abc123")

        #expect(await http.log() == ["DELETE /devices"])
        #expect(await http.body(at: 0) == #"{"deviceToken":"abc123"}"#)
    }

    @Test func aRefusalFromTheRelayIsThrown() async throws {
        let http = StubHTTP()
        await http.reply(to: "/devices", status: 403, json: "{}")
        let relay = try #require(Self.relay(http))
        await #expect(throws: URLError.self) {
            try await relay.register("abc123")
        }
    }

    @Test func anActivityIsReportedWithItsTokenAndCode() async throws {
        let http = StubHTTP()
        await http.reply(to: "/activities", status: 204, json: "")
        try await #require(Self.relay(http)).registerActivity(deviceToken: "dev1", activityToken: "act1", code: "482913")

        let request = try #require(await http.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://relay.example/activities")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
        let body = try JSONDecoder().decode([String: String].self, from: request.httpBody ?? Data())
        #expect(body == ["deviceToken": "dev1", "activityToken": "act1", "code": "482913"])
    }

    @Test func aCopiedCodeIsDismissedEverywhere() async throws {
        let http = StubHTTP()
        await http.reply(to: "/dismiss", status: 204, json: "")
        try await #require(Self.relay(http)).dismissCode("482913")

        #expect(await http.log() == ["POST /dismiss"])
        #expect(await http.body(at: 0) == #"{"code":"482913"}"#)
    }

    @Test func aFailedDismissalIsThrownForTheCallerToIgnore() async throws {
        let http = StubHTTP()
        await http.reply(to: "/dismiss", status: 500, json: "{}")
        let relay = try #require(Self.relay(http))
        await #expect(throws: URLError.self) {
            try await relay.dismissCode("482913")
        }
    }
}
