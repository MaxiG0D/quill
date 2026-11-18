import Foundation
import Testing
@testable import QuillKit

@Suite("MailEvent")
struct MailEventTests {
    private let calendar = Fixture.calendar

    /// Sent Nov 6, 2026, like the dental reminder.
    private var sent: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 9)) ?? .now
    }

    private func at(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, year: Int = 2026) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }

    private func find(_ text: String) -> MailEvent? {
        MailEvent.find(in: text, sentAt: sent, calendar: calendar)
    }

    @Test func readsTheFrenchDentalReminder() {
        let text = """
        Rappel de rendez-vous
        Bonjour Maxime,
        Voici un rappel pour votre rendez-vous chez Clinique Dentaire Rive-Sud Boucherville.
        Date : Mercredi le 18 novembre 2026
        Heure : 10h20
        450-449-0353
        Au plaisir de vous voir!
        """
        let event = find(text)
        #expect(event?.start == at(11, 18, 10, 20))
        #expect(event?.end == nil)
    }

    @Test(arguments: [
        ("Your appointment is on Wed, Nov 18 at 10:20 AM", 11, 18, 10, 20),
        ("Dinner December 3rd, 7pm?", 12, 3, 19, 0),
        ("Rendez-vous le 1er décembre à 9 h", 12, 1, 9, 0),
        ("Le 18/11 à 14h30", 11, 18, 14, 30),
        ("See you 2026-11-20 at 08:15", 11, 20, 8, 15),
        ("Réunion le 20.11.2026 à 16h", 11, 20, 16, 0),
        ("Call tomorrow at 3 p.m.", 11, 7, 15, 0),
        ("Meeting at 2:00 on November 20th, 2026", 11, 20, 2, 0),
        ("Party on the 5th of January, 8:30 pm", 1, 5, 20, 30)
    ])
    func findsTheStart(text: String, month: Int, day: Int, hour: Int, minute: Int) {
        let year = month < 11 ? 2027 : 2026
        #expect(find(text)?.start == at(month, day, hour, minute, year: year))
    }

    @Test func readsRanges() {
        let french = find("mar. 18 nov. de 14h à 15h30")
        #expect(french?.start == at(11, 18, 14))
        #expect(french?.end == at(11, 18, 15, 30))

        let english = find("Workshop 2:00 - 3:30 pm on November 20")
        #expect(english?.start == at(11, 20, 14))
        #expect(english?.end == at(11, 20, 15, 30))
    }

    @Test(arguments: [
        "Votre facture est prête. Montant dû le 21 novembre.",
        "Open 24h, call within 48 h",
        "Call 450-449-0353 at 10:20",
        "Your order shipped on Nov 6",
        "Welcome to Quill"
    ])
    func ignoresMailWithoutBothADateAndATime(text: String) {
        #expect(find(text) == nil)
    }

    @Test func endsAnHourLaterWhenNoEndIsGiven() {
        let event = find("Nov 18 at 10:20")
        #expect(event.map { $0.calendarEnd.timeIntervalSince($0.start) } == 3600)
        #expect(event?.isUpcoming(at: at(11, 18, 11) ?? .now) == true)
        #expect(event?.isUpcoming(at: at(11, 18, 11, 30) ?? .now) == false)
    }

    @Test func titlesRemindersWithTheSender() {
        #expect(EventCalendar.title(subject: "Rappel de rendez-vous", sender: "Clinique Dentaire") == "Clinique Dentaire")
        #expect(EventCalendar.title(subject: "Re: Dinner at Mia's", sender: "Sam") == "Dinner at Mia's")
    }
}
