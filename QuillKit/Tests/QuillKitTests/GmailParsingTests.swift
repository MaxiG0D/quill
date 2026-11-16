import Foundation
import Testing
@testable import QuillKit

struct GmailParsingTests {
    @Test func addressesKeepCommasInsideQuotedNames() {
        let contacts = AddressList.contacts(in: #"Priya Raman <Priya@Example.com>, "Okafor, Dan" <dan@example.com>, bare@example.com, "#)
        #expect(contacts.map(\.name) == ["Priya Raman", "Okafor, Dan", ""])
        #expect(contacts.map(\.email) == ["priya@example.com", "dan@example.com", "bare@example.com"])
        #expect(AddressList.contacts(in: nil).isEmpty)
        #expect(AddressList.contacts(in: "undisclosed-recipients:;").isEmpty)
    }

    @Test func encodedWordsBecomeText() {
        #expect(EncodedWord.decode("=?UTF-8?B?SG9sbGlzIExpYnJhcnkg4oCUIE5ld3M=?=") == "Hollis Library — News")
        #expect(EncodedWord.decode("=?UTF-8?Q?Caf=C3=A9_hours?=") == "Café hours")
        #expect(EncodedWord.decode("=?iso-8859-1?Q?Caf=E9?= menu") == "Café menu")
        #expect(EncodedWord.decode("=?UTF-8?Q?one?=\r\n =?UTF-8?Q?two?=") == "onetwo")
        #expect(EncodedWord.decode("Plain = text?") == "Plain = text?")
    }

    @Test func htmlBecomesReadableText() {
        let html = "<html><head><style>p{color:red}</style></head><body><p>Fall hours &amp; events</p><ul><li>Mon</li><li>Tue</li></ul><div>Open late.<br>See you&nbsp;soon &#8212; Hollis &#x263A;</div><!-- note --></body></html>"
        #expect(HTMLText.plain(from: html) == "Fall hours & events\n\n• Mon\n• Tue\n\nOpen late.\nSee you soon — Hollis ☺")
    }

    @Test func quotedMailIsSetApartFromTheReply() {
        let reply = QuotedText.split("Thanks, signing tonight.\n\nOn Tue, Nov 11, Priya Raman wrote:\n> Hi Max,\n>\n> The renewal is attached.")
        #expect(reply.body == "Thanks, signing tonight.")
        #expect(reply.quoted == "On Tue, Nov 11, Priya Raman wrote:\nHi Max,\n\nThe renewal is attached.")

        let wrapped = QuotedText.split("Sounds good.\n\nOn Tue, Nov 11, 2025 at 9:12 AM Priya Raman <priya@example.com>\nwrote:\n> Hi")
        #expect(wrapped.body == "Sounds good.")

        let plain = QuotedText.split("On reflection, no.\nOn we go.")
        #expect(plain.body == "On reflection, no.\nOn we go.")
        #expect(plain.quoted == nil)
    }

    @Test func outgoingMailCarriesHeadersAndAnEncodedBody() throws {
        let draft = Draft(
            to: [Contact(name: "Priya Raman", email: "priya@example.com")],
            cc: [Contact(name: "", email: "dan@example.com")],
            subject: "Café on Friday",
            body: "See you there.",
            threadID: "t1",
            quoted: "Where?\n\nPriya"
        )
        let anchor = ReplyAnchor(latestMessageID: "m2", messageID: "<two@mail.example>", references: "<one@mail.example>")
        let raw = String(decoding: OutgoingMail.data(for: draft, from: GmailFixture.me, replyingTo: anchor), as: UTF8.self)
        let parts = raw.components(separatedBy: "\r\n\r\n")
        let headers = try #require(parts.first)

        #expect(headers.contains("From: \"Max\" <max@example.com>"))
        #expect(headers.contains("To: \"Priya Raman\" <priya@example.com>"))
        #expect(headers.contains("Cc: dan@example.com"))
        #expect(headers.contains("Subject: =?UTF-8?B?Q2Fmw6kgb24gRnJpZGF5?="))
        #expect(headers.contains("In-Reply-To: <two@mail.example>"))
        #expect(headers.contains("References: <one@mail.example> <two@mail.example>"))

        let body = try #require(Data(base64Encoded: parts[1], options: .ignoreUnknownCharacters))
        #expect(String(decoding: body, as: UTF8.self) == "See you there.\n\n> Where?\n>\n> Priya")
    }

    @Test func base64URLRoundTripsWithoutPadding() {
        let data = Data([0xFB, 0xFF, 0xFE, 0x01])
        #expect(data.base64URLEncoded == "-__-AQ")
        #expect(Data(base64URLEncoded: "-__-AQ") == data)
    }
}
