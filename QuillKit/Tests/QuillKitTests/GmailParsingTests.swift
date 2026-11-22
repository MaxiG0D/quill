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

    @Test func designedMailKeepsItsHTML() throws {
        func html(_ parts: [(type: String, content: String)]) throws -> String? {
            let children = parts.map { #"{"mimeType":"\#($0.type)","body":{"size":1,"data":"\#(GmailFixture.base64URL($0.content))"}}"# }
            let json = #"{"mimeType":"multipart/alternative","parts":[\#(children.joined(separator: ","))]}"#
            return MessageContent.designedHTML(of: try JSONDecoder().decode(GmailResource.Part.self, from: Data(json.utf8)))
        }
        let note = "<div>See you at six.</div>"
        let designed = "<TABLE><tr><td><img src=\"https://example.com/a.png\"></td></tr></table>"

        #expect(try html([("text/plain", "See you at six."), ("text/html", note)]) == nil)
        #expect(try html([("text/plain", "Sale"), ("text/html", designed)]) == designed)
        #expect(try html([("text/html", note)]) == note)
        #expect(try html([("text/plain", "See you at six.")]) == nil)
    }

    @Test func aMessagePageHoldsTheMessageAndStaysLight() {
        let page = HTMLDocument.page(for: "<p>Hello</p>")
        #expect(page.contains(#"<div id="quill-message"><p>Hello</p></div>"#))
        #expect(page.contains("light only"))
    }

    @Test func aSendersViewportIsDropped() {
        let page = HTMLDocument.page(for: #"<META name="Viewport" content="width=600"><p>Hi</p>"#)
        #expect(!page.contains("width=600"))
        #expect(page.contains("<p>Hi</p>"))
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

    @Test func htmlTextSeparatesTableCellsAndDecodesFrenchEntities() {
        let html = "<table><tr><td>Date:</td><td>18&nbsp;novembre</td></tr></table><p>Caf&eacute; &laquo;&nbsp;Ouvert&nbsp;&raquo; 10&euro;</p>"
        #expect(HTMLText.plain(from: html) == "Date: 18 novembre\n\nCafé « Ouvert » 10€")
    }

    @Test func htmlDocumentDropsMetaRefresh() {
        let page = HTMLDocument.page(for: #"<meta http-equiv="refresh" content="0;url=https://evil.example"><p>Hi</p>"#)
        #expect(!page.contains("evil.example"))
        #expect(page.contains("<p>Hi</p>"))
    }

    @Test func outgoingMailSupportsBccAndMultipartHTML() {
        let draft = Draft(
            to: [Contact(name: "Priya", email: "priya@example.com")],
            bcc: [Contact(name: "", email: "secret@example.com")],
            subject: "Hello",
            body: "Bold text",
            htmlBody: "<strong>Bold text</strong>"
        )
        let raw = String(decoding: OutgoingMail.data(for: draft, from: GmailFixture.me), as: UTF8.self)
        #expect(raw.contains("Bcc: secret@example.com"))
        #expect(raw.contains("Content-Type: multipart/alternative"))
        #expect(raw.contains("Content-Type: text/html; charset=UTF-8"))
    }

    @Test func frenchQuotedAttributionIsSplit() {
        let reply = QuotedText.split("Parfait, merci !\n\nLe mar. 11 nov. 2025, Priya Raman a écrit :\n> Bonjour")
        #expect(reply.body == "Parfait, merci !")
        #expect(reply.quoted?.contains("Bonjour") == true)
    }

    @Test func encodedWordJoinsSplitUTF8BytesAcrossAdjacentWords() {
        // "é" (C3 A9) split across two adjacent UTF-8 encoded words.
        #expect(EncodedWord.decode("=?UTF-8?Q?Caf=C3?= =?UTF-8?Q?=A9?=") == "Café")
    }

    @Test func addressListStripsCommentsAndUnwrapsGroups() {
        let contacts = AddressList.contacts(in: "Team: alice@example.com (Alice), Bob <bob@example.com>;")
        #expect(contacts.map(\.email) == ["alice@example.com", "bob@example.com"])
        #expect(contacts.map(\.name) == ["Alice", "Bob"])
    }

    @Test func outgoingMailEncodesAttachmentsAsMultipartMixed() {
        let file = Attachment(filename: "note.txt", byteCount: 5, mimeType: "text/plain", data: Data("hello".utf8))
        let draft = Draft(
            to: [Contact(name: "Priya", email: "priya@example.com")],
            subject: "Attached",
            body: "See attached.",
            attachments: [file]
        )
        let raw = String(decoding: OutgoingMail.data(for: draft, from: GmailFixture.me), as: UTF8.self)
        #expect(raw.contains("Content-Type: multipart/mixed"))
        #expect(raw.contains("Content-Disposition: attachment; filename=\"note.txt\""))
        #expect(raw.contains(Data("hello".utf8).base64EncodedString()))
    }
}
