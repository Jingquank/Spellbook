import XCTest

@MainActor
final class SpellbookUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.menuButtons["Library View"].exists)
    }

    func testAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))
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
                || (elementType == .popUpButton && element.label == "emoji & symbols")
        }
    }

    func testLaunchesInDarkAppearance() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        app.launch()

        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.menuButtons["Library View"].exists)
    }

    func testManageInspectorCanBeCollapsedAndRestored() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))

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

    func testFixedDetailTitleBarOwnsTitleMoreAndManageWithoutToolbarContainers() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-fixture")
        app.launch()
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))

        let titleBar = app.descendants(matching: .any)["Skill title bar"]
        XCTAssertTrue(titleBar.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Fixed skill title"].exists)

        let more = titleBar.descendants(matching: .any)["More actions"]
        XCTAssertTrue(more.waitForExistence(timeout: 3))
        XCTAssertTrue(titleBar.buttons["Toggle Manage Inspector"].exists)
        XCTAssertFalse(app.toolbars.descendants(matching: .any)["More actions"].exists)
        XCTAssertFalse(app.toolbars.buttons["Toggle Manage Inspector"].exists)
        XCTAssertFalse(app.toolbars.staticTexts["Spellbook"].exists)
    }

    func testDetailTitleBlurIsReaderScopedAndExpandsWhenManageIsHidden() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-fixture")
        app.launch()
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))

        let titleBar = app.descendants(matching: .any)["Skill title bar"]
        let toggle = app.buttons["Toggle Manage Inspector"]
        let reader = app.scrollViews["Skill detail"]
        let inspector = app.scrollViews["Skill management inspector"]

        XCTAssertTrue(titleBar.waitForExistence(timeout: 3))
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertTrue(reader.waitForExistence(timeout: 3))

        if !inspector.exists {
            toggle.click()
            XCTAssertTrue(inspector.waitForExistence(timeout: 3))
        }

        let splitTitleFrame = titleBar.frame
        let splitInspectorFrame = inspector.frame
        let detailTop = app.windows.firstMatch.frame.minY
        XCTAssertLessThanOrEqual(splitTitleFrame.maxX, splitInspectorFrame.minX + 2)
        XCTAssertEqual(splitTitleFrame.minY, splitInspectorFrame.minY, accuracy: 2)
        XCTAssertEqual(splitTitleFrame.minY, detailTop, accuracy: 2)

        reader.scroll(byDeltaX: 0, deltaY: -500)
        XCTAssertEqual(titleBar.frame.minX, splitTitleFrame.minX, accuracy: 2)
        XCTAssertEqual(titleBar.frame.minY, splitTitleFrame.minY, accuracy: 2)

        toggle.click()
        XCTAssertTrue(inspector.waitForNonExistence(timeout: 3))
        XCTAssertGreaterThan(titleBar.frame.width, splitTitleFrame.width)
        XCTAssertEqual(titleBar.frame.maxX, reader.frame.maxX, accuracy: 2)

        toggle.click()
        XCTAssertTrue(inspector.waitForExistence(timeout: 3))
        XCTAssertEqual(titleBar.frame.width, splitTitleFrame.width, accuracy: 2)
    }

    func testMoreMenuOmitsSkillEditingAndLocalPackageNaming() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-fixture")
        app.launch()
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))

        let more = app.descendants(matching: .any)["More actions"]
        XCTAssertTrue(more.waitForExistence(timeout: 3))
        more.click()

        XCTAssertFalse(app.menuItems["Edit"].exists)
        XCTAssertFalse(app.menuItems["Use Custom Name…"].exists)
        XCTAssertFalse(app.menuItems["Use Repository Title"].exists)
    }

    func testReviewUpdateMovesFromToolbarToTheLargeTitleHeader() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-fixture")
        app.launch()
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))

        app.buttons["Check for Updates"].click()
        XCTAssertTrue(app.staticTexts["Review updates"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].click()

        let review = app.buttons["Review Update"]
        XCTAssertTrue(review.waitForExistence(timeout: 3))
        XCTAssertFalse(app.toolbars.buttons["Review Update"].exists)
        XCTAssertTrue(app.staticTexts["Alpha Fixture"].exists)
    }

    func testSettingsSidebarMatchesLibraryLayout() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))

        app.buttons["Settings"].click()

        let sidebar = app.descendants(matching: .any)["Settings sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 8))
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
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))

        let mainWindow = app.windows.firstMatch
        let mainCloseButton = mainWindow.buttons[XCUIIdentifierCloseWindow]
        let mainSidebarToggle = mainWindow.buttons["Hide Sidebar"]
        XCTAssertTrue(mainCloseButton.exists)
        XCTAssertTrue(mainSidebarToggle.exists)

        app.buttons["Settings"].click()

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
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))
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
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 2))
    }

    func testSearchEntryFilteringAndClearing() {
        let app = XCUIApplication()
        app.launch()

        let searchField = app.textFields["Search skills"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.click()
        searchField.typeText("unlikely-skill-query")

        XCTAssertEqual(searchField.value as? String, "unlikely-skill-query")

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(searchField.value as? String, "")
        XCTAssertTrue(app.scrollViews["Library sidebar"].waitForExistence(timeout: 3))
    }

    func testClickingAcrossAGroupRowTogglesAndPersists() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["Search skills"].waitForExistence(timeout: 8))
        let scanningIndicator = app.activityIndicators["Scanning skills"]
        if scanningIndicator.exists {
            XCTAssertTrue(scanningIndicator.waitForNonExistence(timeout: 20))
        }

        let groups = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Package group ")
        )
        guard groups.count > 0 else {
            throw XCTSkip("The current test library has no package groups")
        }

        let group = groups.firstMatch
        let label = group.label
        let initialValue = group.value as? String
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5)).click()

        let expectedValue = initialValue == "Expanded" ? "Collapsed" : "Expanded"
        let toggleExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedValue),
            object: group
        )
        XCTAssertEqual(XCTWaiter.wait(for: [toggleExpectation], timeout: 3), .completed)

        app.terminate()
        app.launch()
        let restoredGroup = app.buttons[label]
        XCTAssertTrue(restoredGroup.waitForExistence(timeout: 8))
        XCTAssertEqual(restoredGroup.value as? String, expectedValue)
    }
}
