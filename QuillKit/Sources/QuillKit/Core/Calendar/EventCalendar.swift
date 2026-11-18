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

    @MainActor
    static func add(_ event: MailEvent, title: String, messageID: String) async -> Outcome {
        let outcome = await save(start: event.start, end: event.calendarEnd, title: title)
        if case .added = outcome {
            var added = UserDefaults.standard.stringArray(forKey: addedKey) ?? []
            added.append(messageID)
            UserDefaults.standard.set(Array(added.suffix(500)), forKey: addedKey)
        }
        return outcome
    }

    /// Writes the event with write-only access, so Quill never reads the calendar.
    private static func save(start: Date, end: Date, title: String) async -> Outcome {
        let store = EKEventStore()
        do {
            guard try await store.requestWriteOnlyAccessToEvents() else { return .denied }
            let item = EKEvent(eventStore: store)
            item.title = title
            item.startDate = start
            item.endDate = end
            item.calendar = store.defaultCalendarForNewEvents
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
