import XCTest

final class RoutePilotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["createGPX"].waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        if let app {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testPreviewPauseResumeStop() {
        app.buttons["Preview"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
        app.buttons["Stop preview"].tap()
        XCTAssertTrue(app.buttons["Preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Preview"].isEnabled)
    }

    func testGPXCreatesShareableFileAndValidatesPace() {
        app.buttons["createGPX"].tap()
        XCTAssertTrue(app.navigationBars["Create GPX"].waitForExistence(timeout: 5))
        let pace = app.textFields["Pace in minutes per km"]
        XCTAssertTrue(pace.exists)
        replaceText(pace, with: "0:00")
        let create = app.buttons["createExportFile"]
        reveal(create)
        XCTAssertFalse(create.isEnabled)
        replaceText(pace, with: "6:00")
        app.toolbars.buttons["Done"].firstMatch.tap()
        reveal(create)
        XCTAssertTrue(create.isEnabled)
        create.tap()
        XCTAssertTrue(app.buttons["Save to Files or share GPX"].waitForExistence(timeout: 10))
    }

    func testConnectionHasAutomaticPortAndManualOverride() {
        app.buttons["iPhone setup"].tap()
        XCTAssertTrue(app.navigationBars["iPhone connection"].waitForExistence(timeout: 5))
        let advanced = app.buttons["Advanced connection settings"]
        reveal(advanced); advanced.tap()
        let automatic = app.switches["automaticPort"]
        XCTAssertTrue(automatic.waitForExistence(timeout: 5))
        if automatic.value as? String == "0" { automatic.switches.firstMatch.tap() }
        XCTAssertFalse(app.textFields["Developer port"].exists)
        automatic.switches.firstMatch.tap()
        XCTAssertTrue(app.textFields["Developer port"].waitForExistence(timeout: 5))
        automatic.switches.firstMatch.tap()
        let help = app.buttons["First-time setup"]
        reveal(help); help.tap()
        let wifi = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Show this iPhone when on Wi-Fi")).firstMatch
        reveal(wifi)
        XCTAssertTrue(wifi.exists)
    }

    func testCoordinatesRejectMalformedInput() {
        let coordinates = app.buttons["Coordinates"]
        reveal(coordinates); coordinates.tap()
        let alert = app.alerts["Add coordinates"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.textFields.firstMatch.tap()
        alert.textFields.firstMatch.typeText("37, bad, -122")
        alert.buttons["Add"].tap()
        XCTAssertTrue(app.alerts["RoutePilot"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts["RoutePilot"].staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Enter latitude")).firstMatch.exists)
    }

    func testDarkLandscapeLayout() {
        app.terminate()
        app.launchArguments = ["--ui-testing", "--ui-testing-dark"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["createGPX"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Preview"].isHittable)
        // Exercise a sheet after rotation so the screenshot observes settled layout.
        app.buttons["iPhone setup"].tap()
        XCTAssertTrue(app.navigationBars["iPhone connection"].waitForExistence(timeout: 5))
        app.navigationBars["iPhone connection"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Preview"].waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        print("LANDSCAPE WINDOW: \(window)")
        for name in ["Preview", "Start on iPhone", "createGPX", "iPhone setup", "Search locations", "Fit route"] {
            let control = app.buttons[name]
            print("LANDSCAPE CONTROL \(name): \(control.frame)")
            XCTAssertTrue(window.insetBy(dx: -1, dy: -1).contains(control.frame), "\(name) must remain within the app window")
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dark landscape"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCheckpointDragRemoveAndUndo() {
        let pin = app.buttons["checkpoint-1"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        let beforeDrag = XCTAttachment(screenshot: app.screenshot())
        beforeDrag.name = "Map before drag"; beforeDrag.lifetime = .keepAlways; add(beforeDrag)
        let start = pin.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 1.5, thenDragTo: start.withOffset(CGVector(dx: 24, dy: 18)))
        let undo = app.buttons["Undo"]
        reveal(undo)
        XCTAssertTrue(undo.isEnabled)
        undo.tap()
        // Bring the map back into view before testing short-tap removal.
        app.swipeDown()
        app.buttons["checkpoint-1"].tap()
        let count = app.staticTexts["checkpointCount"]
        reveal(count)
        XCTAssertTrue(count.label.contains("2/24"))
        reveal(undo); undo.tap()
        XCTAssertTrue(app.buttons["checkpoint-3"].waitForExistence(timeout: 5))
    }

    func testLargeTextControlsRemainReachable() {
        app.terminate()
        app.launchArguments = ["--ui-testing", "--ui-testing-large-text"]
        app.launch()
        XCTAssertTrue(app.buttons["createGPX"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Preview"].isHittable)
        app.buttons["createGPX"].tap()
        XCTAssertTrue(app.navigationBars["Create GPX"].waitForExistence(timeout: 5))
    }

    private func replaceText(_ field: XCUIElement, with text: String) {
        field.tap()
        field.press(forDuration: 1.2)
        let menuItem = app.menuItems["Select All"]
        let menuButton = app.buttons["Select All"]
        if menuItem.waitForExistence(timeout: 1) { menuItem.tap() }
        else if menuButton.exists { menuButton.tap() }
        field.typeText(text)
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
    }
}
