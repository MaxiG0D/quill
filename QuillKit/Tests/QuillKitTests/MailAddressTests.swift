import Foundation
import Testing
@testable import QuillKit

@Suite("MailAddress")
struct MailAddressTests {
    @Test func readsAFrenchCanadianBlock() {
        let text = """
        Au plaisir de vous voir!

        Clinique Dentaire Rive-Sud Boucherville
        450-449-0353

        500 Rue d'Avaugour, Bureau 2010
        Boucherville, Quebec, canada
        J4B 0G6
        """
        let address = MailAddress.find(in: text)
        #expect(address?.street == "500 Rue d'Avaugour, Bureau 2010")
        #expect(address?.locality == "Boucherville, Quebec, canada, J4B 0G6")
    }

    @Test func splitsAOneLineAddress() {
        let address = MailAddress.find(in: "Find us at\n120 Main St, Springfield, IL 62701\nSee you")
        #expect(address?.street == "120 Main St")
        #expect(address?.locality == "Springfield, IL 62701")
    }

    @Test func readsAFrenchPostcode() {
        let address = MailAddress.find(in: "Rendez-vous au\n12 avenue des Champs-Élysées\n75008 Paris")
        #expect(address?.full == "12 avenue des Champs-Élysées, 75008 Paris")
    }

    @Test func skipsBulkMailFooters() {
        let text = """
        Our winter sale starts today. Everything is 30% off.

        You are receiving this email because you signed up.
        Unsubscribe | Privacy Policy
        Acme Inc, 1 Market Street, San Francisco, CA 94105
        """
        #expect(MailAddress.find(in: text) == nil)
    }

    @Test func skipsFrenchFooters() {
        let text = """
        Les soldes commencent.

        Pour vous désabonner, cliquez ici.
        1000 Rue Sherbrooke Ouest, Montréal, QC H3A 3G4
        """
        #expect(MailAddress.find(in: text) == nil)
    }

    @Test func skipsSignatures() {
        let text = """
        Thanks for the notes, talk soon.

        --
        Jane Doe
        200 King Street West, Toronto, ON M5H 3T4
        """
        #expect(MailAddress.find(in: text) == nil)
    }

    @Test func skipsShippingAndBillingAddresses() {
        let shipping = """
        Your package is on its way.
        Shipping to:
        Max Gariepy
        42 Rue Principale
        Granby, QC J2G 2T6
        """
        #expect(MailAddress.find(in: shipping) == nil)

        let billing = "Adresse de facturation\n42 Rue Principale, Granby, QC J2G 2T6"
        #expect(MailAddress.find(in: billing) == nil)
    }

    @Test func needsAStreet() {
        #expect(MailAddress.find(in: "We have 3 items left\nShips from QC H3A 3G4") == nil)
        #expect(MailAddress.find(in: "Your code is 4821 for Springfield, IL 62701") == nil)
    }

    @Test func keepsTheVenueAboveAFooter() {
        let text = """
        Join us for the launch party at
        1150 Boulevard René-Lévesque Ouest
        Montréal, QC H3B 4P8

        © 2026 Events Co. All rights reserved.
        """
        #expect(MailAddress.find(in: text)?.street == "1150 Boulevard René-Lévesque Ouest")
    }

    @Test func readsAStreetOnItsOwnLine() {
        let text = """
        Si vous devez modifier votre rendez-vous, contactez-nous au (450) 468-9999.

        (450) 468-9999
        1251 Chemin du Tremblay

        Pour vous désabonner des courriels, cliquez ici.
        """
        let address = MailAddress.find(in: text)
        #expect(address?.street == "1251 Chemin du Tremblay")
        #expect(address?.locality == "")
    }

    @Test func leavesSentencesWithAStreetAlone() {
        #expect(MailAddress.find(in: "We moved 3 desks to the Main St office last week.") == nil)
        #expect(MailAddress.find(in: "Shipping to\n42 Rue Principale") == nil)
    }
}
