import Combine
import EventKit
import SwiftUI

/// An event found in a message, at the top of it, with a button that adds it to the calendar.
struct EventCard: View {
    let event: MailEvent
    let details: EventDetails
    let messageID: String

    @Environment(MailStore.self) private var store: MailStore?
    @State private var state: AddState = .ready
    @State private var added = 0
    @State private var calendars: [EventCalendar.Choice] = []
    @State private var picksCalendar = false
    @State private var errorMessage: String?
    @Environment(\.scenePhase) private var scenePhase

    private enum AddState {
        case ready, adding, added, denied
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                CalendarTile(date: event.start)
                VStack(alignment: .leading, spacing: 1) {
                    Text(EventDateText.day(event.start, now: store?.now ?? .now))
                        .font(.headline)
                        .foregroundStyle(Palette.label)
                    Text(EventDateText.time(event))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.secondaryLabel)
                }
                .lineLimit(1)
                Spacer(minLength: Spacing.xs)
                button
            }
            if let errorMessage {
                Text(errorMessage)
                    .textRole(.meta)
                    .foregroundStyle(Palette.destructive)
                    .padding(.leading, Spacing.xxs)
            }
        }
        .padding(Spacing.xs + 2)
        .frame(maxWidth: 440, alignment: .leading)
        .background(Palette.accentTint, in: .rect(cornerRadius: Radius.medium))
        .sensoryFeedback(.success, trigger: added)
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) {
            if scenePhase == .active { refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: EventCalendar.changed).receive(on: RunLoop.main)) { _ in
            refresh()
        }
    }

    /// Follows the calendar: an event deleted there brings Add back, and granted permission clears Allow.
    private func refresh() {
        guard state != .adding else { return }
        if EventCalendar.isAdded(messageID) {
            state = .added
            errorMessage = nil
        } else if state == .added {
            withAnimation(Motion.quick) { state = .ready }
        } else if state == .denied, EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            withAnimation(Motion.quick) { state = .ready }
            errorMessage = nil
        }
    }

    @ViewBuilder
    private var button: some View {
        switch state {
        case .ready, .adding:
            Button {
                Task { await chooseCalendar() }
            } label: {
                Group {
                    if state == .adding {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Palette.onFill)
                    } else {
                        Label("Add", systemImage: "plus")
                    }
                }
                .foregroundStyle(Palette.onFill)
                .modifier(EventButtonShape(filled: true))
            }
            .buttonStyle(.pressable)
            .disabled(state == .adding)
            .help("Add to Calendar")
            .accessibilityLabel("Add to Calendar")
            .popover(isPresented: $picksCalendar) {
                CalendarPicker(calendars: calendars) { calendar in
                    picksCalendar = false
                    Task { await add(to: calendar) }
                }
                .presentationCompactAdaptation(.popover)
            }
        case .added:
            Button {
                EventCalendar.open(event)
            } label: {
                Label("Added", systemImage: "checkmark")
                    .foregroundStyle(Palette.accent)
                    .modifier(EventButtonShape(filled: false))
            }
            .buttonStyle(.pressable)
            .help("Open in Calendar")
            .accessibilityLabel("Open in Calendar")
        case .denied:
            Button {
                EventCalendar.openSettings()
            } label: {
                Label("Allow", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(Palette.accent)
                    .modifier(EventButtonShape(filled: false))
            }
            .buttonStyle(.pressable)
            .help("Allow Calendar access in Settings")
            .accessibilityLabel("Allow Calendar access in Settings")
        }
    }

    /// Asks which calendar to use, unless there is only one.
    private func chooseCalendar() async {
        errorMessage = nil
        state = .adding
        guard let choices = await EventCalendar.choices() else {
            withAnimation(Motion.quick) { state = .denied }
            return
        }
        guard !choices.isEmpty else {
            withAnimation(Motion.quick) {
                state = .ready
                errorMessage = "No writable calendar available."
            }
            return
        }
        if choices.count == 1 {
            await add(to: choices[0])
        } else {
            calendars = choices
            state = .ready
            picksCalendar = true
        }
    }

    private func add(to calendar: EventCalendar.Choice) async {
        errorMessage = nil
        state = .adding
        switch await EventCalendar.add(event, details: details, to: calendar, messageID: messageID) {
        case .added:
            withAnimation(Motion.quick) { state = .added }
            added += 1
        case .denied:
            withAnimation(Motion.quick) { state = .denied }
        case .failed:
            withAnimation(Motion.quick) {
                state = .ready
                errorMessage = "Couldn’t save event to Calendar."
            }
        }
    }
}

/// The calendars to add to, each with its color.
private struct CalendarPicker: View {
    let calendars: [EventCalendar.Choice]
    let pick: (EventCalendar.Choice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add to Calendar")
                .textRole(.meta)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.secondaryLabel)
                .padding(.horizontal, Spacing.m)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xs)
            Divider().overlay(Palette.separator)
            if calendars.count > 8 {
                ScrollView { list }
                    .frame(height: 320)
            } else {
                list
            }
        }
        .frame(minWidth: 240, maxWidth: 280)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(calendars) { calendar in
                CalendarPickerRow(calendar: calendar) {
                    pick(calendar)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.xs)
    }
}

private struct CalendarPickerRow: View {
    let calendar: EventCalendar.Choice
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Circle()
                    .fill(Color(.sRGB, red: calendar.red, green: calendar.green, blue: calendar.blue))
                    .frame(width: 10, height: 10)
                Text(calendar.title)
                    .foregroundStyle(Palette.label)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: Metrics.target)
            .background(isHovering ? Palette.fill : .clear, in: .rect(cornerRadius: Radius.small))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct EventButtonShape: ViewModifier {
    let filled: Bool

    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, Spacing.s + 2)
            .padding(.vertical, Spacing.xs - 1)
            .background {
                if filled {
                    Capsule().fill(Palette.accentFill)
                } else {
                    Capsule().strokeBorder(Palette.accent, lineWidth: 1.5)
                }
            }
            .contentShape(.capsule)
    }
}

/// A small calendar page: the month over the day.
private struct CalendarTile: View {
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(date.formatted(.dateTime.day()))
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.label)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 2)
        .frame(width: 44, height: 46)
        .background(Palette.surface, in: .rect(cornerRadius: Radius.small))
        .accessibilityHidden(true)
    }
}

/// An upcoming event on a list row: "Today 10:20", "Fri 18:45", "Dec 4 18:45".
struct EventChip: View {
    let event: MailEvent
    let now: Date
    /// True when rendered on `Palette.accentTint` (selected row or pinned card).
    var onTint = false

    var body: some View {
        Label {
            Text(EventDateText.short(event.start, now: now))
        } icon: {
            Image(systemName: "calendar")
        }
        .labelStyle(EventChipLabelStyle())
        .textRole(.chip)
        .lineLimit(1)
        .foregroundStyle(Palette.accent)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 3)
        .background(onTint ? Palette.surface : Palette.accentTint, in: .capsule)
        .accessibilityLabel("Event \(EventDateText.short(event.start, now: now))")
    }
}

private struct EventChipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

/// How events read on the card and the chip.
enum EventDateText {
    static func day(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Today") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return String(localized: "Tomorrow")
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    static func time(_ event: MailEvent) -> String {
        let start = event.start.formatted(date: .omitted, time: .shortened)
        guard let end = event.end else { return start }
        return "\(start) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    static func short(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        let day: String = switch days {
        case 0: String(localized: "Today")
        case 1: String(localized: "Tomorrow")
        case 2...6: date.formatted(.dateTime.weekday(.abbreviated))
        default: date.formatted(.dateTime.month(.abbreviated).day())
        }
        return "\(day) \(time)"
    }
}
