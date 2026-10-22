import XCTest

/// Navigation smoke test and retained native screenshots for the secondary tabs.
final class TabAppearanceTests: XCTestCase {
    func testHeroLongPressActivatesOnRelease() {
        let app = XCUIApplication()
        app.launch()
        let hero = app.buttons["届いたメロディ"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        if !hero.isHittable { app.swipeUp() }
        let resting = XCTAttachment(screenshot: app.screenshot())
        resting.name = "press-resting-ios"
        resting.lifetime = .keepAlways
        add(resting)
        // Moving outside the button cancels the action and restores its appearance.
        hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.15)))
        XCTAssertTrue(hero.exists)
        if !hero.isHittable { app.swipeDown() }
        hero.press(forDuration: 5)
        XCTAssertTrue(app.staticTexts["ひとつの出会いから、次の好きへ。"].waitForExistence(timeout: 5))
    }

    func testSecondaryTabsRemainReachable() {
        let app = XCUIApplication()
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 15))
        for (index, title, snapshot) in [(1, "メロディ", "melody"), (2, "コレクション", "collection"), (3, "ランキング", "ranking"), (4, "マイページ", "mypage")] {
            let button = tabs.buttons.element(boundBy: index)
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 5))
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "tabs-\(snapshot)-ios"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
