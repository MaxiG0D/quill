import SwiftUI

/// Sheet for picking an exact date and time to snooze a thread until.
struct CustomSnoozeSheet: View {
    @Environment(MailStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let threadID: MailThread.ID
    @State private var date: Date

    init(threadID: MailThread.ID, defaultDate: Date) {
        self.threadID = threadID
        _date = State(initialValue: defaultDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Snooze Until")
                    .textRole(.title)
                    .foregroundStyle(Palette.label)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                SheetCloseButton(action: { dismiss() })
            }

            DatePicker(
                "Snooze Until",
                selection: $date,
                in: store.now.addingTimeInterval(300)...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            #if os(iOS)
            .datePickerStyle(.graphical)
            #else
            .datePickerStyle(.graphical)
            #endif
            .tint(Palette.accent)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Snooze") {
                    withAnimation(Motion.list) {
                        store.snooze(threadID, until: date)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accentFill)
            }
        }
        .padding(Spacing.l)
        .background(Palette.surface)
        #if os(macOS)
        .frame(width: 340)
        #else
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }
}
