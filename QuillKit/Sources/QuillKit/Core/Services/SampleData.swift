import Foundation

/// The mailbox shown in the design mockups, dated relative to `now`.
enum SampleData {
    /// Thursday, November 13, 2025 at 9:41 AM: the moment the mockups depict.
    static func referenceDate(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: 11, day: 13, hour: 9, minute: 41)) ?? .now
    }

    static let account = Contact(name: "Max", email: "max@example.com", tone: .teal)

    static let family = MailLabel(id: "family", name: "Family", tone: .plum)
    static let house = MailLabel(id: "house", name: "House", tone: .teal)
    static let finances = MailLabel(id: "finances", name: "Finances", tone: .amber)
    static let travel = MailLabel(id: "travel", name: "Travel", tone: .slate)

    static let priya = Contact(name: "Priya Raman", email: "priya@haldenleasing.example", tone: .teal)
    static let haldenLeasing = Contact(name: "Halden Leasing", email: "office@haldenleasing.example", tone: .slate)
    static let dental = Contact(name: "Northfield Dental", email: "hello@northfielddental.example", tone: .slate)
    static let library = Contact(name: "Hollis Public Library", email: "holds@hollislibrary.example", tone: .amber)
    static let dan = Contact(name: "Dan Okafor", email: "dan.okafor@example.com", tone: .olive)
    static let ruth = Contact(name: "Ruth Calloway", email: "ruth.calloway@example.com", tone: .plum)
    static let water = Contact(name: "Cedar Valley Water", email: "billing@cedarvalleywater.example", tone: .amber)
    static let sam = Contact(name: "Sam Whitaker", email: "sam.whitaker@example.com", tone: .slate)
    static let haldenProperty = Contact(name: "Halden Property Group", email: "leasing@haldenproperty.example", tone: .slate)
    static let movers = Contact(name: "Coastal Movers", email: "crew@coastalmovers.example", tone: .amber)
    static let insurance = Contact(name: "Marlow Insurance", email: "service@marlowinsurance.example", tone: .olive)

    static func snapshot(now: Date, calendar: Calendar = .current) -> MailSnapshot {
        // A time of day on the day `daysAgo` days before `now`.
        func at(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        let me = account

        let lease = MailThread(
            id: "lease-renewal",
            subject: "Lease renewal for the apartment",
            messages: [
                Message(
                    id: "lease-1", sender: priya, to: [me], date: at(16, 15, 20),
                    body: "Parking is included, and the lease allows one more space if you ever need it. I can send the full terms whenever you are ready."
                ),
                Message(
                    id: "lease-2", sender: me, to: [priya], date: at(15, 10, 5),
                    body: "Great, that covers everything we asked about. Send the renewal over when it is ready and we will sign."
                ),
                Message(
                    id: "lease-3", sender: priya, to: [me], cc: [haldenLeasing], date: at(0, 9, 12),
                    body: """
                    Hi both,

                    Attached is the updated agreement for the next twelve months. The only change from last year is the parking clause on page 3, which now includes the second space at no extra cost.

                    Could you both sign by Friday so I can file it before the end of the month? A scan or a photo of the signature page is fine.

                    Thanks,
                    Priya
                    """,
                    quoted: "Great, that covers everything we asked about. Send the renewal over when it is ready and we will sign.",
                    attachments: [Attachment(id: "lease-pdf", filename: "Lease_Renewal_2027.pdf", byteCount: 284_000)]
                )
            ],
            labelIDs: [house.id],
            isUnread: true, isStarred: true, isPinned: true
        )

        let appointment = MailThread(
            id: "dental",
            subject: "Appointment on Tuesday",
            messages: [
                Message(
                    id: "dental-1", sender: dental, to: [me], date: at(0, 8, 47),
                    body: "Your cleaning is scheduled for Nov 18 at 3:30 PM with Dr. Alvarez. Reply to this message if you need to move it."
                )
            ],
            isUnread: true
        )

        let holds = MailThread(
            id: "library",
            subject: "Two holds ready for pickup",
            messages: [
                Message(
                    id: "library-1", sender: library, to: [me], date: at(0, 7, 30),
                    body: "Your items are waiting at the front desk until next Thursday. Bring your card or the app to check them out.",
                    unsubscribe: Unsubscribe(
                        list: "<https://hollislibrary.example/unsubscribe>",
                        post: "List-Unsubscribe=One-Click"
                    )
                )
            ],
            labelIDs: [family.id],
            isStarred: true
        )

        let hike = MailThread(
            id: "hike",
            subject: "Saturday hike?",
            messages: [
                Message(
                    id: "hike-1", sender: dan, to: [me], date: at(1, 18, 4),
                    body: "Weather looks clear. Thinking we start at the north trailhead around eight and grab lunch after. You in?"
                )
            ]
        )

        let thanksgiving = MailThread(
            id: "thanksgiving",
            subject: "Thanksgiving plans",
            messages: [
                Message(
                    id: "thanksgiving-1", sender: ruth, to: [me], date: at(1, 14, 30),
                    body: "We would love to host again this year. Let me know how many of you are coming and whether anyone is bringing a dish."
                )
            ],
            labelIDs: [family.id]
        )

        let statement = MailThread(
            id: "water",
            subject: "November statement",
            messages: [
                Message(
                    id: "water-1", sender: water, to: [me], date: at(3, 9, 0),
                    body: "Your statement is ready. Autopay will draft on the 20th from the account ending in 4410.",
                    attachments: [Attachment(id: "water-pdf", filename: "Statement_November.pdf", byteCount: 96_000)]
                )
            ],
            labelIDs: [finances.id],
            snoozedUntil: at(3, 9, 0)
        )

        let photos = MailThread(
            id: "photos",
            subject: "Photos from the weekend",
            messages: [
                Message(
                    id: "photos-1", sender: sam, to: [me], date: at(2, 11, 15),
                    body: "Finally got these off my camera. The lake one came out better than I expected.",
                    attachments: [
                        Attachment(id: "photo-1", filename: "Lake_Morning.jpg", byteCount: 3_400_000),
                        Attachment(id: "photo-2", filename: "Trailhead.jpg", byteCount: 2_900_000)
                    ]
                )
            ],
            labelIDs: [travel.id]
        )

        let questions = MailThread(
            id: "lease-questions",
            subject: "Re: Questions about the lease",
            messages: [
                Message(
                    id: "questions-1", sender: priya, to: [me], date: at(16, 11, 40),
                    body: "Parking is included, and the lease allows a second pet with a small deposit. Nothing else changes from the current terms."
                )
            ],
            labelIDs: [house.id],
            folder: .archive
        )

        let scan = MailThread(
            id: "lease-scan",
            subject: "Signed lease scan",
            messages: [
                Message(
                    id: "scan-1", sender: me, to: [priya], date: at(42, 16, 10),
                    body: "Here is the scanned copy for our records.",
                    attachments: [Attachment(id: "scan-pdf", filename: "Lease_Signed.pdf", byteCount: 512_000)]
                )
            ],
            labelIDs: [house.id],
            folder: .sent
        )

        let unit = MailThread(
            id: "lease-unit",
            subject: "Lease agreement for Unit 4B",
            messages: [
                Message(
                    id: "unit-1", sender: haldenProperty, to: [me], date: at(91, 10, 0),
                    body: "Please review the attached lease before your move-in date and return a signed copy to the leasing office.",
                    attachments: [Attachment(id: "unit-pdf", filename: "Unit_4B_Lease.pdf", byteCount: 640_000)]
                )
            ],
            labelIDs: [house.id],
            folder: .archive
        )

        let firstDraft = MailThread(
            id: "lease-draft",
            subject: "First lease draft",
            messages: [
                Message(
                    id: "draft-1", sender: priya, to: [me], date: at(106, 13, 25),
                    body: "A draft for you both to look over. Nothing is final until the lease is signed, so mark up anything you want changed."
                )
            ],
            folder: .archive
        )

        let move = MailThread(
            id: "movers",
            subject: "Move date confirmed",
            messages: [
                Message(
                    id: "movers-1", sender: movers, to: [me], date: at(134, 9, 30),
                    body: "Your old lease ends the same day, so plan for the crew to arrive at eight and finish by early afternoon."
                )
            ],
            folder: .archive
        )

        let policy = MailThread(
            id: "insurance",
            subject: "Policy renewal",
            messages: [
                Message(
                    id: "insurance-1", sender: insurance, to: [me], date: at(4, 12, 0),
                    body: "Your renters policy renews next month. Review the new premium and coverage before the renewal date."
                )
            ],
            labelIDs: [finances.id],
            snoozedUntil: at(-1, 8, 0)
        )

        let itinerary = MailThread(
            id: "itinerary",
            subject: "Trip itinerary",
            messages: [
                Message(
                    id: "itinerary-1", sender: me, to: [sam], date: at(1, 21, 15),
                    body: "Here is what I have so far for the long weekend. Flights are booked, the cabin is still a maybe."
                )
            ],
            labelIDs: [travel.id],
            folder: .drafts
        )

        return MailSnapshot(
            account: me,
            labels: [family, house, finances, travel],
            threads: [
                lease, appointment, holds, hike, thanksgiving, statement, photos,
                questions, scan, unit, firstDraft, move, policy, itinerary
            ]
        )
    }
}
