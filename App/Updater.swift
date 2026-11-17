#if os(macOS)
import Combine
import Sparkle
import SwiftUI

/// Quill's updates on the Mac. Sparkle checks the appcast named by `SUFeedURL` in the
/// background and asks before installing. It stays off until `SUPublicEDKey` holds a key,
/// which `Scripts/release-mac.sh setup` writes.
@MainActor
final class Updater: ObservableObject {
    @Published private(set) var canCheck = false
    private let controller: SPUStandardUpdaterController

    init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        controller = SPUStandardUpdaterController(
            startingUpdater: !key.isEmpty,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
    }

    func check() {
        controller.checkForUpdates(nil)
    }
}

struct UpdateCommands: Commands {
    @ObservedObject var updater: Updater

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…", action: updater.check)
                .disabled(!updater.canCheck)
        }
    }
}
#endif
