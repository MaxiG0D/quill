import SwiftUI

/// The account's picture, which opens Settings: a sheet on iOS, the Settings window on macOS.
struct SettingsButton: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    var size = MonogramAvatar.Size.compact

    var body: some View {
        Button(action: show) {
            MonogramAvatar(store.account, size: size)
                .clipShape(.circle)
                .overlay {
                    Circle().strokeBorder(Palette.separator, lineWidth: 1)
                }
                .shadow(color: .black.opacity(size == .compact ? 0 : 0.06), radius: 12, y: 4)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Settings")
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
