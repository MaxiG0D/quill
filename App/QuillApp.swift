import QuillKit
import SwiftUI

@main
struct QuillApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(QuillAppDelegate.self) private var delegate
    #else
    @NSApplicationDelegateAdaptor(QuillAppDelegate.self) private var delegate
    #endif

    #if os(macOS)
    @StateObject private var updater = Updater()
    #endif

    var body: some Scene {
        let scene = QuillScene(googleClientID: Configuration.googleClientID, pushRelayURL: Configuration.pushRelayURL)
        #if os(macOS)
        scene.commands { UpdateCommands(updater: updater) }
        #else
        scene
        #endif
    }
}
