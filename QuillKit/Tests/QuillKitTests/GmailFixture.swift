import Foundation
@testable import QuillKit

/// Canned Gmail responses for a small mailbox.
enum GmailFixture {
    static let client = GoogleClient(id: "1234-abcd.apps.googleusercontent.com")!
    static let me = Contact(name: "Max", email: "max@example.com", tone: .teal)

    static func token(expiresIn seconds: TimeInterval = 3600, from now: Date = .now) -> OAuthToken {
        OAuthToken(accessToken: "access", refreshToken: "refresh", expiry: now.addingTimeInterval(seconds))
    }

    static func base64URL(_ text: String) -> String {
        Data(text.utf8).base64URLEncoded
    }

    static let userInfo = #"{"email":"Max@Example.com","name":"Max"}"#

    static let labels = """
        {"labels":[
          {"id":"INBOX","name":"INBOX","type":"system"},
          {"id":"Label_2","name":"Travel","type":"user"},
          {"id":"Label_1","name":"House","type":"user"}
        ]}
        """

    /// A two-message conversation in the inbox: a note from Priya with a PDF, then Max's reply quoting it.
    static var leaseThread: String {
        let first = base64URL("Hi Max,\r\n\r\nThe renewal is attached.\r\n\r\nPriya")
        let reply = base64URL("Thanks, signing tonight.\n\nOn Tue, Nov 11, Priya Raman wrote:\n> Hi Max,\n>\n> The renewal is attached.")
        return """
            {"id":"t1","historyId":"100","messages":[
              {"id":"m1","labelIds":["INBOX","UNREAD","Label_1"],"internalDate":"1762900000000","payload":{
                "mimeType":"multipart/mixed",
                "headers":[
                  {"name":"From","value":"Priya Raman <Priya@HaldenLeasing.example>"},
                  {"name":"To","value":"Max <max@example.com>, \\"Okafor, Dan\\" <dan@example.com>"},
                  {"name":"Subject","value":"Lease renewal"},
                  {"name":"Message-ID","value":"<one@mail.example>"}
                ],
                "parts":[
                  {"partId":"0","mimeType":"multipart/alternative","parts":[
                    {"partId":"0.0","mimeType":"text/plain","body":{"size":40,"data":"\(first)"}},
                    {"partId":"0.1","mimeType":"text/html","body":{"size":80,"data":"\(base64URL("<p>Hi Max,</p>"))"}}
                  ]},
                  {"partId":"1","mimeType":"application/pdf","filename":"Lease.pdf","body":{"size":48211,"attachmentId":"att1"}}
                ]}},
              {"id":"m2","labelIds":["SENT","STARRED"],"internalDate":"1762903600000","payload":{
                "mimeType":"text/plain",
                "headers":[
                  {"name":"from","value":"max@example.com"},
                  {"name":"To","value":"Priya Raman <priya@haldenleasing.example>"},
                  {"name":"Subject","value":"Re: Lease renewal"},
                  {"name":"Message-ID","value":"<two@mail.example>"},
                  {"name":"References","value":"<one@mail.example>"}
                ],
                "body":{"size":90,"data":"\(reply)"}}}
            ]}
            """
    }

    /// A newsletter that is HTML only and has been archived.
    static var newsletterThread: String {
        let html = base64URL("<html><head><style>p{color:red}</style></head><body><p>Fall hours &amp; events</p><div>Open late on Thursdays.<br>See you soon&nbsp;&#8212; Hollis</div></body></html>")
        return """
            {"id":"t2","historyId":"200","messages":[
              {"id":"m3","labelIds":["CATEGORY_UPDATES"],"internalDate":"1762800000000","payload":{
                "mimeType":"text/html",
                "headers":[
                  {"name":"From","value":"=?UTF-8?B?SG9sbGlzIExpYnJhcnkg4oCUIE5ld3M=?= <news@hollis.example>"},
                  {"name":"Subject","value":"=?UTF-8?Q?Caf=C3=A9_hours?="}
                ],
                "body":{"size":120,"data":"\(html)"}}}
            ]}
            """
    }

    /// A stub that serves the mailbox above.
    static func mailbox() async -> StubHTTP {
        let http = StubHTTP()
        await http.reply(to: "/userinfo", json: userInfo)
        await http.reply(to: "/labels", json: labels)
        await http.reply(to: "/threads?", json: #"{"threads":[{"id":"t1","historyId":"100"},{"id":"t2","historyId":"200"}]}"#)
        await http.reply(to: "labelIds=TRASH", json: "{}")
        await http.reply(to: "/threads/t1?", json: leaseThread)
        await http.reply(to: "/threads/t2?", json: newsletterThread)
        return http
    }

    static func service(http: StubHTTP, file: MailArchiveFile? = nil) -> GmailMailService {
        let auth = GoogleAuth(client: client, http: http, tokens: MemoryTokenStore(token()))
        return GmailMailService(api: GmailAPI(auth: auth, http: http), file: file)
    }
}
