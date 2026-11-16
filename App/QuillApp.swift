import QuillKit
import SwiftUI

@main
struct QuillApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(QuillAppDelegate.self) private var delegate
    #else
    @NSApplicationDelegateAdaptor(QuillAppDelegate.self) private var delegate
    #endif

    var body: some Scene {
        QuillScene(googleClientID: Configuration.googleClientID, pushRelayURL: Configuration.pushRelayURL)
    }
}
