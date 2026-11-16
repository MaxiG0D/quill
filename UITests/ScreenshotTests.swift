import XCTest

/// Launches the app in each state the mockups show and saves a screenshot of it.
/// The screenshots are attached to the test report, where CI collects them.
@MainActor
final class ScreenshotTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testInboxLight() { capture("inbox", appearance: "light") }
    func testInboxDark() { capture("inbox", appearance: "dark") }
    func testThreadLight() { capture("thread", appearance: "light") }
    func testThreadDark() { capture("thread", appearance: "dark") }
    func testSearch() { capture("search", appearance: "light") }
    func testCompose() { capture("compose", appearance: "light") }
    func testMailboxes() { capture("mailboxes", appearance: "light") }
    func testSettings() { capture("settings", appearance: "light") }
    func testInboxZero() { capture("zero", appearance: "light") }

    private func capture(_ screen: String, appearance: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-QuillScreen", screen, "-QuillAppearance", appearance]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))

        // Give sheets and pushes time to settle before the picture is taken.
        Thread.sleep(forTimeInterval: 2)

        #if os(macOS)
        let screenshot = app.windows.firstMatch.screenshot()
        #else
        let screenshot = XCUIScreen.main.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(screen)-\(appearance)"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }
}
