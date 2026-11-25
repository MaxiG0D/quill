import SwiftUI

/// Which app address cards open.
struct MapsAppPicker: View {
    @AppStorage(MapsApp.storageKey) private var stored = ""

    var body: some View {
        HStack {
            Text("Maps")
                .font(.body)
                .foregroundStyle(Palette.label)
            Spacer(minLength: Spacing.s)
            Picker("Maps", selection: selection) {
                ForEach(MapsApp.allCases) { app in
                    Text(app.title).tag(app)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var selection: Binding<MapsApp> {
        Binding(
            get: { MapsApp(rawValue: stored) ?? MapsApp.current },
            set: { stored = $0.rawValue }
        )
    }
}
