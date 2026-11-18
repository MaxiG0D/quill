import CoreGraphics
import EventKit
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Adds events found in mail to the user's calendar, and remembers which messages it added.
enum EventCalendar {
    enum Outcome: Sendable {
        case added
        case denied
        case failed
    }

    private static let addedKey = "calendar.addedMessages"

    /// The calendar title for an event: the sender for reminders such as "Rappel de rendez-vous",
    /// the subject otherwise.
    static func title(subject: String, sender: String) -> String {
        let generic = subject.range(
            of: #"\b(?:rappel|reminder|rendez-vous|rdv|appointment|confirmation)\b"#,
            options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]
        ) != nil
        let trimmed = subject.replacingOccurrences(
            of: #"^\s*(?:(?:re|tr|fwd?|fw)\s*:\s*)+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        if (generic || trimmed.isEmpty) && !sender.isEmpty { return sender }
        return trimmed
    }

    @MainActor
    static func isAdded(_ messageID: String) -> Bool {
        UserDefaults.standard.stringArray(forKey: addedKey)?.contains(messageID) ?? false
    }

    /// A calendar the user can add to.
    struct Choice: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let red: Double
        let green: Double
        let blue: Double
    }

    private static let lastCalendarKey = "calendar.lastUsed"

    /// The calendars the user can add to, the last one used first, then the default.
    /// Nil when the user has not allowed Quill to see them.
    @MainActor
    static func choices() async -> [Choice]? {
        guard let found = await writableCalendars() else { return nil }
        let (all, defaultID) = found
        let last = UserDefaults.standard.string(forKey: lastCalendarKey)
        func rank(_ choice: Choice) -> Int {
            choice.id == last ? 0 : choice.id == defaultID ? 1 : 2
        }
        return all.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    @MainActor
    static func add(_ event: MailEvent, details: EventDetails, to calendar: Choice?, messageID: String) async -> Outcome {
        let outcome = await save(start: event.start, end: event.calendarEnd, details: details, calendarID: calendar?.id)
        if case .added = outcome {
            var added = UserDefaults.standard.stringArray(forKey: addedKey) ?? []
            added.append(messageID)
            UserDefaults.standard.set(Array(added.suffix(500)), forKey: addedKey)
            if let calendar { UserDefaults.standard.set(calendar.id, forKey: lastCalendarKey) }
        }
        return outcome
    }

    private static func writableCalendars() async -> ([Choice], String?)? {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToEvents()) == true else { return nil }
        let calendars = store.calendars(for: .event).filter(\.allowsContentModifications)
        let titles = calendars.map(\.title)
        let choices = calendars.map { calendar in
            // Two calendars named "Calendar" read apart by their account.
            let shared = titles.filter { $0 == calendar.title }.count > 1
            let title = shared ? "\(calendar.title) · \(calendar.source?.title ?? "")" : calendar.title
            let rgb = calendar.cgColor
                .flatMap { $0.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) }?
                .components ?? [0.5, 0.5, 0.5]
            return Choice(
                id: calendar.calendarIdentifier,
                title: title,
                red: Double(rgb[0]),
                green: Double(rgb.count > 2 ? rgb[1] : rgb[0]),
                blue: Double(rgb.count > 2 ? rgb[2] : rgb[0])
            )
        }
        return (choices, store.defaultCalendarForNewEvents?.calendarIdentifier)
    }

    private static func save(start: Date, end: Date, details: EventDetails, calendarID: String?) async -> Outcome {
        let store = EKEventStore()
        do {
            let allowed: Bool
            if calendarID == nil {
                allowed = try await store.requestWriteOnlyAccessToEvents()
            } else {
                allowed = try await store.requestFullAccessToEvents()
            }
            guard allowed else { return .denied }
            let item = EKEvent(eventStore: store)
            item.title = details.title
            item.location = details.location
            item.notes = details.notes
            item.startDate = start
            item.endDate = end
            item.calendar = calendarID.flatMap { store.calendar(withIdentifier: $0) } ?? store.defaultCalendarForNewEvents
            try store.save(item, span: .thisEvent)
            return .added
        } catch {
            return .failed
        }
    }

    /// Opens Calendar on the event's day.
    @MainActor
    static func open(_ event: MailEvent) {
        #if canImport(UIKit)
        if let url = URL(string: "calshow:\(Int(event.start.timeIntervalSinceReferenceDate))") {
            UIApplication.shared.open(url)
        }
        #else
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: app, configuration: .init(), completionHandler: nil)
        }
        #endif
    }

    /// Opens the system setting that lets Quill add events.
    @MainActor
    static func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

/// Events found in messages, kept so list rows do not search every message on each redraw.
@MainActor
enum MailEventCache {
    private static var found: [String: MailEvent?] = [:]

    static func event(in message: Message, subject: String) -> MailEvent? {
        let source = message.body.isEmpty ? message.snippet ?? "" : message.body
        let key = "\(message.id):\(source.count)"
        if let cached = found[key] { return cached }
        let event = MailEvent.find(in: subject + "\n" + source, sentAt: message.date)
        if found.count > 2000 { found.removeAll() }
        found[key] = event
        return event
    }
}
