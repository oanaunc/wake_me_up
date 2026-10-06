import XCTest
import StoreKitTest

final class WakeUITests: XCTestCase {
    @MainActor func app() -> XCUIApplication {
        let app=XCUIApplication(); app.launchArguments=["-welcomed","YES","-ui-demo"]; app.launch(); return app
    }
    @MainActor func testPushupPracticeRequiresFiveCountsAndEarnsNoStreak() {
        let app=app()
        app.buttons["Move"].firstMatch.tap()
        reveal(app.buttons["practice-pushups"],in:app);app.buttons["practice-pushups"].tap()
        app.buttons["start-guided"].tap()
        for _ in 0..<5 { app.buttons["count-rep"].tap() }
        XCTAssertTrue(app.buttons["save-sunrise"].waitForExistence(timeout:3))
        app.buttons["save-sunrise"].tap()
        app.buttons["Sunrises"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your first sunrise is waiting."].waitForExistence(timeout:3))
    }
    @MainActor func testFollowSunRequiresEightCorrectTaps() {
        let app=app()
        let tile=app.buttons["mission-sunTaps"];reveal(tile,in:app);tile.tap()
        app.buttons["start-guided"].tap()
        for _ in 0..<8 { let sun=app.buttons["sun-target"]; if !sun.isHittable { app.swipeUp() }; sun.tap() }
        XCTAssertTrue(app.buttons["save-sunrise"].waitForExistence(timeout:3))
    }
    @MainActor func testAlarmEditorAndRingtoneChoices() {
        let app=app()
        app.buttons["add-first-alarm"].tap()
        XCTAssertTrue(app.textFields["alarm-label"].waitForExistence(timeout:3))
        reveal(app.buttons["Preview selected sound"],in:app)
        XCTAssertTrue(app.buttons["Preview selected sound"].isHittable)
        app.buttons["Cancel"].tap()
    }
    @MainActor func testScreenshots() {
        let app=app()
        capture(app,"01-morning")
        app.buttons["add-first-alarm"].tap(); XCTAssertTrue(app.textFields["alarm-label"].waitForExistence(timeout:5)); capture(app,"02-alarm"); app.buttons["Cancel"].tap()
        app.buttons["Move"].firstMatch.tap(); capture(app,"03-move")
        reveal(app.buttons["practice-pushups"],in:app);app.buttons["practice-pushups"].tap(); app.buttons["start-guided"].tap(); capture(app,"04-challenge")
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
    @MainActor func reveal(_ element:XCUIElement,in app:XCUIApplication) {
        for _ in 0..<14 {if element.isHittable {return};app.swipeUp()}
        XCTAssertTrue(element.isHittable)
    }
    @MainActor func testMathsAndWordsRequireCorrectAnswers() {
        let app=app();app.buttons["Move"].firstMatch.tap()
        reveal(app.buttons["practice-math"],in:app);app.buttons["practice-math"].tap();app.buttons["start-guided"].tap()
        for _ in 0..<3 {
            let text=app.staticTexts["math-prompt"].label
            let parts=text.split(separator:" ");let answer=Int(parts[0])!+Int(parts[2])!
            app.textFields["math-answer"].tap();app.textFields["math-answer"].typeText(String(answer))
            if app.buttons["math-keyboard-done"].isHittable {app.buttons["math-keyboard-done"].tap()}
            reveal(app.buttons["math-submit"],in:app);app.buttons["math-submit"].tap()
        }
        XCTAssertTrue(app.buttons["save-sunrise"].waitForExistence(timeout:3));app.buttons["save-sunrise"].tap()
        reveal(app.buttons["practice-words"],in:app);app.buttons["practice-words"].tap();app.buttons["start-guided"].tap()
        let field=app.textFields["intention-answer"];reveal(field,in:app);field.tap();field.typeText("Today I will start small.")
        if app.buttons["words-keyboard-done"].isHittable {app.buttons["words-keyboard-done"].tap()}
        reveal(app.buttons["intention-submit"],in:app);app.buttons["intention-submit"].tap()
        XCTAssertTrue(app.buttons["save-sunrise"].waitForExistence(timeout:3))
    }
    @MainActor func testMemoryTrailAndReplay() {
        let app=app();app.buttons["Move"].firstMatch.tap()
        reveal(app.buttons["practice-memory"],in:app);app.buttons["practice-memory"].tap();app.buttons["start-guided"].tap()
        for _ in 0..<3 {
            var order:[(Int,Int)]=[]
            for spot in 0..<4 {
                let label=app.buttons["memory-spot-\(spot)"].label
                if let last=label.split(separator:",").last,let number=Int(last.trimmingCharacters(in:.whitespaces)) {order.append((number,spot))}
            }
            reveal(app.buttons["memory-ready"],in:app);app.buttons["memory-ready"].tap()
            for (_,spot) in order.sorted(by:{$0.0 < $1.0}) {
                let tile=app.buttons["memory-spot-\(spot)"];if !tile.isHittable {app.swipeDown()};tile.tap()
            }
        }
        XCTAssertTrue(app.buttons["save-sunrise"].waitForExistence(timeout:3))
    }
    @MainActor func testMultiStepPracticeDoesNotCreateJournalCredit() {
        let app=app();app.buttons["Move"].firstMatch.tap();app.buttons["practice-whole-route"].tap();app.buttons["start-guided"].tap()
        for _ in 0..<8 {let sun=app.buttons["sun-target"];reveal(sun,in:app);sun.tap()}
        app.buttons["next-route-step"].tap()
        XCTAssertTrue(app.staticTexts["Gentle stretch"].waitForExistence(timeout:4));app.buttons["start-guided"].tap()
        XCTAssertTrue(app.buttons["next-route-step"].waitForExistence(timeout:35));app.buttons["next-route-step"].tap()
        app.buttons["start-guided"].tap()
        let light=app.buttons["I've let in some light"];reveal(light,in:app);light.tap()
        XCTAssertTrue(app.buttons["save-sunrise"].waitForExistence(timeout:3));app.buttons["save-sunrise"].tap()
        app.buttons["Sunrises"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your first sunrise is waiting."].exists)
    }
    @MainActor func testMorningToolsAndRouteEditor() {
        let app=app();app.buttons["morning-tools"].tap()
        XCTAssertTrue(app.buttons["set-quick-nap"].exists)
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["add-first-alarm"].tap()
        reveal(app.buttons["build-route"],in:app);app.buttons["build-route"].tap()
        reveal(app.buttons["add-route-step"],in:app);app.buttons["add-route-step"].tap()
        XCTAssertTrue(app.staticTexts["Step 2 · Let in the light"].exists)
        app.buttons["Cancel"].tap()
    }
    @MainActor func testNewFeatureScreenshots() {
        let app=app();app.buttons["morning-tools"].tap();capture(app,"10-morning-tools")
        reveal(app.buttons["Open bedside clock"],in:app);app.buttons["Open bedside clock"].tap();capture(app,"11-bedside");app.buttons["Close"].tap()
        app.navigationBars.buttons.element(boundBy:0).tap();app.buttons["add-first-alarm"].tap()
        reveal(app.buttons["build-route"],in:app);app.buttons["build-route"].tap();app.buttons["add-route-step"].tap();capture(app,"12-route-editor");app.buttons["Cancel"].tap()
        app.buttons["Move"].firstMatch.tap();reveal(app.buttons["practice-math"],in:app);app.buttons["practice-math"].tap();app.buttons["start-guided"].tap();capture(app,"13-maths")
        app.swipeDown();app.swipeDown();app.buttons["Exit ritual"].tap();app.buttons["Exit without saving a sunrise"].tap()
        reveal(app.buttons["practice-memory"],in:app);app.buttons["practice-memory"].tap();app.buttons["start-guided"].tap();capture(app,"14-memory")
    }
    @MainActor func testNativeSnoozeAndWakeCheck() throws {
        guard ProcessInfo.processInfo.environment["WAKE_ALARM_TEST"] == "1" else {throw XCTSkip("Run the signed alarm integration scheme.")}
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let app=XCUIApplication();app.launchArguments=["-welcomed","YES","-alarm-integration","-snooze-integration"];app.launch()
        app.buttons["schedule-integration"].tap();if springboard.buttons["Allow"].waitForExistence(timeout:3) {springboard.buttons["Allow"].tap()}
        XCTAssertTrue(app.staticTexts["Integration sunrise · Once"].waitForExistence(timeout:10))
        XCUIDevice.shared.press(.home)
        let snooze=springboard.buttons["Snooze"];XCTAssertTrue(snooze.waitForExistence(timeout:35));capture(springboard,"15-native-snooze");snooze.tap()
        app.activate();XCTAssertFalse(app.buttons["start-guided"].exists)
        app.terminate();app.launchArguments=["-welcomed","YES","-alarm-integration","-check-integration"];app.launch()
        app.buttons["schedule-integration"].tap();XCTAssertTrue(app.staticTexts["Integration sunrise · Once"].waitForExistence(timeout:10));XCUIDevice.shared.press(.home)
        let start=springboard.buttons["Start moving"];XCTAssertTrue(start.waitForExistence(timeout:35));start.tap()
        XCTAssertTrue(app.buttons["start-guided"].waitForExistence(timeout:10));app.buttons["start-guided"].tap()
        for _ in 0..<8 {let sun=app.buttons["sun-target"];reveal(sun,in:app);sun.tap()}
        app.buttons["save-sunrise"].tap();XCUIDevice.shared.press(.home)
        XCTAssertTrue(start.waitForExistence(timeout:35));capture(springboard,"16-native-wake-check");start.tap()
        XCTAssertTrue(app.buttons["awake-confirm"].waitForExistence(timeout:10))
        for _ in 0..<3 {app.buttons["awake-confirm"].tap()}
        app.buttons["Yes, I'm awake"].tap();app.buttons["Sunrises"].firstMatch.tap();capture(app,"17-confirmed-check")
        XCTAssertFalse(app.staticTexts["Your first sunrise is waiting."].exists)
    }
    @MainActor func capture(_ app:XCUIApplication,_ name:String) {
        let image=XCTAttachment(screenshot:app.screenshot()); image.name=name; image.lifetime = .keepAlways; add(image)
    }
}
