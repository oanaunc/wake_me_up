import XCTest
import StoreKitTest

final class WakeUITests: XCTestCase {
    @MainActor func app() -> XCUIApplication {
        let app=XCUIApplication(); app.launchArguments=["-welcomed","YES","-ui-demo"]; app.launch(); return app
    }
    @MainActor func testPushupPracticeRequiresFiveCountsAndEarnsNoStreak() {
        let app=app()
        app.buttons["Move"].firstMatch.tap()
        app.buttons["practice-pushups"].tap()
        app.buttons["start-guided"].tap()
        for _ in 0..<5 { app.buttons["count-rep"].tap() }
        XCTAssertTrue(app.buttons["save-sunrise"].waitForExistence(timeout:3))
        app.buttons["save-sunrise"].tap()
        app.buttons["Sunrises"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your first sunrise is waiting."].waitForExistence(timeout:3))
    }
    @MainActor func testFollowSunRequiresEightCorrectTaps() {
        let app=app()
        let tile=app.buttons["mission-sunTaps"]; app.swipeUp(); if !tile.isHittable { app.swipeUp() }; tile.tap()
        app.buttons["start-guided"].tap()
        for _ in 0..<8 { let sun=app.buttons["sun-target"]; if !sun.isHittable { app.swipeUp() }; sun.tap() }
        XCTAssertTrue(app.buttons["save-sunrise"].waitForExistence(timeout:3))
    }
    @MainActor func testAlarmEditorAndRingtoneChoices() {
        let app=app()
        app.buttons["add-first-alarm"].tap()
        XCTAssertTrue(app.textFields["alarm-label"].waitForExistence(timeout:3))
        app.swipeUp(); app.swipeUp(); app.swipeUp()
        XCTAssertTrue(app.buttons["Preview selected sound"].exists)
        app.buttons["Cancel"].tap()
    }
    @MainActor func testScreenshots() {
        let app=app()
        capture(app,"01-morning")
        app.buttons["add-first-alarm"].tap(); XCTAssertTrue(app.textFields["alarm-label"].waitForExistence(timeout:5)); capture(app,"02-alarm"); app.buttons["Cancel"].tap()
        app.buttons["Move"].firstMatch.tap(); capture(app,"03-move")
        app.buttons["practice-pushups"].tap(); app.buttons["start-guided"].tap(); capture(app,"04-challenge")
        for _ in 0..<5 { app.buttons["count-rep"].tap() }; capture(app,"05-sunrise"); app.buttons["save-sunrise"].tap()
        app.buttons["Sunrises"].firstMatch.tap(); capture(app,"06-journal")
        app.buttons["Settings"].firstMatch.tap(); capture(app,"07-settings")
    }
    @MainActor func testSystemAlarmOpensRitualFromBackground() throws {
        guard ProcessInfo.processInfo.environment["WAKE_ALARM_TEST"] == "1" else { throw XCTSkip("Run WakeAlarmIntegration on a simulator or unlocked device.") }
        addUIInterruptionMonitor(withDescription:"Alarm authorization") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        let app=XCUIApplication(); app.launchArguments=["-welcomed","YES","-alarm-integration"]; app.launch()
        XCTAssertTrue(app.staticTexts["Hello, sunshine."].waitForExistence(timeout:20))
        app.buttons["schedule-integration"].tap()
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let allow=springboard.buttons["Allow"]
        if allow.waitForExistence(timeout:5) { allow.tap() }
        guard app.staticTexts["Integration sunrise · Once"].waitForExistence(timeout:10) else { capture(app,"alarm-setup-failure"); XCTFail(app.debugDescription); return }
        XCUIDevice.shared.press(.home)
        let start=springboard.buttons["Start moving"]
        XCTAssertTrue(start.waitForExistence(timeout:35))
        capture(springboard,"09-system-alarm"); start.tap()
        XCTAssertTrue(app.buttons["start-guided"].waitForExistence(timeout:10))
        app.buttons["start-guided"].tap()
        for _ in 0..<8 { let sun=app.buttons["sun-target"]; if !sun.isHittable { app.swipeUp() }; sun.tap() }
        app.buttons["save-sunrise"].tap()
        app.buttons["Sunrises"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Your first sunrise is waiting."].exists)
    }
    @MainActor func testSubscriptionPurchaseAndRestore() throws {
        guard ProcessInfo.processInfo.environment["WAKE_STOREKIT_TEST"] == "1" else { throw XCTSkip("Run WakeStoreKit from Xcode to enable local StoreKit testing.") }
        let session=try SKTestSession(configurationFileNamed:"WakeProducts")
        session.resetToDefaultState(); session.disableDialogs=true; try session.clearTransactions()
        defer { withExtendedLifetime(session) {} }
        let app=app()
        app.buttons["Settings"].firstMatch.tap(); app.buttons["Explore Plus"].tap()
        let price=app.staticTexts["$19.99 / year"]
        for _ in 0..<4 { if price.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(price.waitForExistence(timeout:15))
        let purchase=app.buttons["Subscribe · $19.99 / year"]
        if !purchase.isHittable { app.swipeUp() }; capture(app,"08-plus"); purchase.tap()
        XCTAssertTrue(app.staticTexts["Plus is active. Welcome, sunshine."].waitForExistence(timeout:15))
        app.buttons["Done"].tap(); app.buttons["Restore purchases"].tap()
        XCTAssertTrue(app.staticTexts["Your Plus subscription is restored."].waitForExistence(timeout:15))
    }
    @MainActor func capture(_ app:XCUIApplication,_ name:String) {
        let image=XCTAttachment(screenshot:app.screenshot()); image.name=name; image.lifetime = .keepAlways; add(image)
    }
}
