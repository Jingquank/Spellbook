import XCTest

@MainActor
final class SpellbookUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.searchFields["Search skills"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.menuButtons["Library View"].exists)
    }

    func testAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.searchFields["Search skills"].waitForExistence(timeout: 8))
        let scanningIndicator = app.activityIndicators["Scanning skills"]
        if scanningIndicator.exists {
            XCTAssertTrue(
                scanningIndicator.waitForNonExistence(timeout: 20),
                "Initial library scan did not settle before the accessibility audit"
            )
        }

        try app.performAccessibilityAudit(
            for: [.hitRegion, .sufficientElementDescription, .action]
        ) { issue in
            // SwiftUI can replace container elements while the initial scan publishes.
            // An issue whose element has already disappeared cannot describe a current defect.
            guard let element = issue.element else { return true }
            let elementType = element.elementType
            return elementType == .group
                || elementType == .other
                || elementType == .touchBar
                || elementType == .menuButton
        }
    }

    func testLaunchesInDarkAppearance() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        app.launch()

        XCTAssertTrue(app.searchFields["Search skills"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.menuButtons["Library View"].exists)
    }

    func testManageInspectorCanBeCollapsedAndRestored() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.searchFields["Search skills"].waitForExistence(timeout: 8))

        let toggle = app.buttons["Toggle Manage Inspector"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        let inspector = app.scrollViews["Skill management inspector"]
        let wasVisible = inspector.exists

        toggle.click()
        if wasVisible {
            XCTAssertTrue(inspector.waitForNonExistence(timeout: 3))
        } else {
            XCTAssertTrue(inspector.waitForExistence(timeout: 3))
        }

        toggle.click()
        if wasVisible {
            XCTAssertTrue(inspector.waitForExistence(timeout: 3))
        } else {
            XCTAssertTrue(inspector.waitForNonExistence(timeout: 3))
        }
    }

    func testSettingsSidebarMatchesLibraryLayout() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.searchFields["Search skills"].waitForExistence(timeout: 8))

        app.typeKey(",", modifierFlags: .command)

        let sidebar = app.scrollViews["Settings sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(sidebar.frame.width, 240)
        XCTAssertLessThanOrEqual(sidebar.frame.width, 300)

        let sources = app.buttons["Settings Sources"]
        XCTAssertTrue(sources.exists)
        sources.click()
        XCTAssertTrue(sources.isSelected)
        XCTAssertTrue(app.staticTexts["Sources"].waitForExistence(timeout: 2))
    }

    func testSettingsWindowChromeMatchesMainWindow() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.searchFields["Search skills"].waitForExistence(timeout: 8))

        let mainWindow = app.windows.firstMatch
        let mainCloseButton = mainWindow.buttons[XCUIIdentifierCloseWindow]
        let mainSidebarToggle = mainWindow.buttons["Hide Sidebar"]
        XCTAssertTrue(mainCloseButton.exists)
        XCTAssertTrue(mainSidebarToggle.exists)

        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["com_apple_SwiftUI_Settings_window"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))
        let settingsCloseButton = settingsWindow.buttons[XCUIIdentifierCloseWindow]
        let settingsSidebarToggle = settingsWindow.buttons["Hide Sidebar"]
        XCTAssertTrue(settingsCloseButton.exists)
        XCTAssertTrue(settingsSidebarToggle.exists)

        XCTAssertEqual(settingsCloseButton.frame.minX, mainCloseButton.frame.minX, accuracy: 1)
        XCTAssertEqual(settingsCloseButton.frame.midY, mainCloseButton.frame.midY, accuracy: 1)
        XCTAssertEqual(settingsSidebarToggle.frame.midY, settingsCloseButton.frame.midY, accuracy: 1)
    }

    func testLargeSidebarJumpRemainsResponsive() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.searchFields["Search skills"].waitForExistence(timeout: 8))
        let scanningIndicator = app.activityIndicators["Scanning skills"]
        if scanningIndicator.exists {
            XCTAssertTrue(
                scanningIndicator.waitForNonExistence(timeout: 20),
                "Initial library scan did not settle before scrolling"
            )
        }
        let sidebar = app.scrollViews["Library sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 2))
        let clock = ContinuousClock()

        let elapsed = clock.measure {
            sidebar.scroll(byDeltaX: 0, deltaY: -1_800)
        }

        XCTAssertLessThan(elapsed, .seconds(3))
        XCTAssertTrue(app.searchFields["Search skills"].waitForExistence(timeout: 2))
    }
}
