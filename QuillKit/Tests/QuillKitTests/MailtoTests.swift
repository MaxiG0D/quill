import Foundation
import Testing
@testable import QuillKit

struct MailtoTests {
    @Test func fillsEveryField() throws {
        let url = try #require(URL(string: "mailto:a@x.com,Bea%20Roy%20%3Cbea@x.com%3E?cc=c@x.com&bcc=d@x.com&subject=Hello%20there&body=Line%201%0D%0ALine%202"))
        let draft = try #require(Draft(mailto: url))
        #expect(draft.to.map(\.email) == ["a@x.com", "bea@x.com"])
        #expect(draft.to.last?.name == "Bea Roy")
        #expect(draft.cc.map(\.email) == ["c@x.com"])
        #expect(draft.bcc.map(\.email) == ["d@x.com"])
        #expect(draft.subject == "Hello there")
        #expect(draft.body == "Line 1\nLine 2")
    }

    @Test func readsRecipientsFromTheQueryToo() throws {
        let url = try #require(URL(string: "MAILTO:?to=a@x.com&TO=b@x.com,a@x.com&Subject=Hi+there"))
        let draft = try #require(Draft(mailto: url))
        #expect(draft.to.map(\.email) == ["a@x.com", "b@x.com"])
        #expect(draft.subject == "Hi+there")
    }

    @Test func ignoresOtherLinks() throws {
        #expect(Draft(mailto: try #require(URL(string: "https://x.com"))) == nil)
        let empty = try #require(Draft(mailto: try #require(URL(string: "mailto:"))))
        #expect(empty.to.isEmpty && empty.subject.isEmpty && empty.body.isEmpty)
    }
}
