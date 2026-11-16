import QuillKit
import SwiftUI

@main
struct QuillApp: App {
    var body: some Scene {
        QuillScene(googleClientID: Configuration.googleClientID)
    }
}
