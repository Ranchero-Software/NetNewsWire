import XCTest
#if os(macOS)
import AppKit
import ApplicationServices
#endif

@MainActor
final class ReaderSmokeTests: XCTestCase {
    func testConnectionFormIsReachableWithoutNetwork() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        recordAccessibilityDiagnosis()
        let connect = app.buttons["connectFreshRSS"]
        XCTAssertTrue(connect.waitForExistence(timeout: 15))
        connect.clickOrTap()
        XCTAssertTrue(app.textFields["serverURL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["username"].exists)
        XCTAssertTrue(app.secureTextFields["apiPassword"].exists)
        XCTAssertFalse(app.buttons["submitConnection"].isEnabled)
        app.buttons["Abbrechen"].firstMatch.clickOrTap()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
    }

    #if os(macOS)
    func testNewWindowHasIndependentConnectionForm() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        recordAccessibilityDiagnosis()
        XCTAssertTrue(app.buttons["connectFreshRSS"].waitForExistence(timeout: 15))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.windows.element(boundBy: 1).waitForExistence(timeout: 5))
        let first = app.windows.element(boundBy: 0)
        let second = app.windows.element(boundBy: 1)
        second.buttons["connectFreshRSS"].click()
        let username = app.textFields["username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        username.click()
        username.typeText("Fenster B")
        app.buttons["Abbrechen"].firstMatch.click()
        first.buttons["connectFreshRSS"].click()
        XCTAssertTrue(app.textFields["username"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["username"].value as? String, "")
        app.buttons["Abbrechen"].firstMatch.click()
        XCTAssertTrue(second.buttons["connectFreshRSS"].exists)
    }
    #endif

    private func recordAccessibilityDiagnosis() {
        #if os(macOS)
        let entries = NSRunningApplication.runningApplications(withBundleIdentifier: "eu.mpwg.reader.debug").map { application in
            let element = AXUIElementCreateApplication(application.processIdentifier)
            var windows: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows)
            return "pid=\(application.processIdentifier), active=\(application.isActive), AXWindowsStatus=\(result.rawValue), windowCount=\((windows as? [AXUIElement])?.count ?? -1)"
        }
        let diagnosis = "AXIsProcessTrusted=\(AXIsProcessTrusted()); " + entries.joined(separator: "; ")
        let attachment = XCTAttachment(string: diagnosis)
        attachment.name = "Accessibility-Diagnose"
        attachment.lifetime = .keepAlways
        add(attachment)
        #endif
    }
}

private extension XCUIElement {
    func clickOrTap() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}
