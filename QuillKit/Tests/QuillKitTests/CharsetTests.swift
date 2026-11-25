import Foundation
import Testing
@testable import QuillKit

struct CharsetTests {
    private let french = "Vous avez demandé que l’on vous contacte. Vous êtes prêt."

    @Test func utf8LabeledAsLatin1StaysUTF8() {
        let data = Data(french.utf8)
        #expect(MessageContent.text(from: data, declared: .isoLatin1) == french)
        #expect(MessageContent.text(from: data, declared: .windowsCP1252) == french)
        #expect(MessageContent.text(from: data, declared: nil) == french)
    }

    @Test func realLatin1StillDecodes() {
        let data = "café êtes".data(using: .isoLatin1)!
        #expect(MessageContent.text(from: data, declared: .isoLatin1) == "café êtes")
    }

    @Test func repairsDoubleDecodedText() {
        #expect(MessageContent.repairingMojibake("demandÃ© lâ€™avez Ã¢tes") == "demandé l’avez âtes")
        #expect(MessageContent.repairingMojibake("Ã©Ã¨") == "éè")
    }

    @Test func leavesNormalTextAlone() {
        #expect(MessageContent.repairingMojibake("Â© 2026 Ça va") == "Â© 2026 Ça va")
        #expect(MessageContent.repairingMojibake(french) == french)
    }
}
