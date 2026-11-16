import SwiftUI

/// The gear that opens Settings: a sheet on iOS, the Settings window on macOS.
struct SettingsButton: View {
    @Environment(Router.self) private var router
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    var body: some View {
        IconButton("Settings", systemImage: "gearshape", action: show)
            .foregroundStyle(Palette.secondaryLabel)
            #if os(macOS)
            .task {
                // A screenshot launch asks for Settings before there is a window to open it from.
                if router.isShowingSettings { show() }
            }
            #endif
    }

    private func show() {
        #if os(macOS)
        router.isShowingSettings = false
        openSettings()
        #else
        router.isShowingSettings = true
        #endif
    }
}

extension View {
    /// Presents Settings over this view on iOS. macOS shows Settings in its own window.
    @ViewBuilder
    func settingsSheet(isPresented: Binding<Bool>) -> some View {
        #if os(iOS)
        self.sheet(isPresented: isPresented) {
            SettingsView()
        }
        #else
        self
        #endif
    }
}
