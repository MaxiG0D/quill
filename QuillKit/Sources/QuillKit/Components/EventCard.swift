import SwiftUI

/// An event found in a message, at the top of it, with a button that adds it to the calendar.
struct EventCard: View {
    let event: MailEvent
    let title: String
    let messageID: String

    @State private var state: AddState = .ready
    @State private var added = 0

    private enum AddState {
        case ready, adding, added, denied
    }

    var body: some View {
        HStack(spacing: Spacing.s) {
            CalendarTile(date: event.start)
            VStack(alignment: .leading, spacing: 1) {
                Text(EventDateText.day(event.start, now: .now))
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
        .padding(Spacing.xs + 2)
        .frame(maxWidth: 440, alignment: .leading)
        .background(Palette.accentTint, in: .rect(cornerRadius: Radius.medium))
        .sensoryFeedback(.success, trigger: added)
        .onAppear {
            if EventCalendar.isAdded(messageID) { state = .added }
        }
    }

    @ViewBuilder
    private var button: some View {
        switch state {
        case .ready, .adding:
            Button {
                Task { await add() }
            } label: {
                Label("Add", systemImage: "plus")
                    .foregroundStyle(Palette.onFill)
                    .modifier(EventButtonShape(filled: true))
            }
            .buttonStyle(.plain)
            .disabled(state == .adding)
            .accessibilityLabel("Add to Calendar")
        case .added:
            Button {
                EventCalendar.open(event)
            } label: {
                Label("Added", systemImage: "checkmark")
                    .foregroundStyle(Palette.accent)
                    .modifier(EventButtonShape(filled: false))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open in Calendar")
        case .denied:
            Button {
                EventCalendar.openSettings()
            } label: {
                Label("Allow", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(Palette.accent)
                    .modifier(EventButtonShape(filled: false))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Allow Calendar access in Settings")
        }
    }

    private func add() async {
        state = .adding
        switch await EventCalendar.add(event, title: title, messageID: messageID) {
        case .added:
            withAnimation(Motion.quick) { state = .added }
            added += 1
        case .denied:
            withAnimation(Motion.quick) { state = .denied }
        case .failed:
            state = .ready
        }
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
            Text(date.formatted(.dateTime.day()))
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.label)
        }
        .frame(width: 44, height: 46)
        .background(Palette.surface, in: .rect(cornerRadius: Radius.small))
        .accessibilityHidden(true)
    }
}

/// An upcoming event on a list row: "Today 10:20", "Fri 18:45", "Dec 4 18:45".
struct EventChip: View {
    let event: MailEvent
    let now: Date

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
        .background(Palette.accentTint, in: .capsule)
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
