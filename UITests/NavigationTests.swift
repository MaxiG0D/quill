import XCTest

/// Checks the paths a person takes most: opening a thread and starting a message.
@MainActor
final class NavigationTests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-QuillScreen", "inbox"]
        app.launch()
        return app
    }

    func testOpeningAThreadShowsItsSubject() {
        let app = launch()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Appointment on Tuesday")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()

        let heading = app.staticTexts["thread-heading"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 10))
        XCTAssertEqual(heading.label, "Appointment on Tuesday")
    }

    func testComposeOpensANewMessage() {
        let app = launch()
        let compose = app.buttons["Compose"].firstMatch
        XCTAssertTrue(compose.waitForExistence(timeout: 20))
        compose.tap()

        let title = app.staticTexts["New Message"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
    }
}
