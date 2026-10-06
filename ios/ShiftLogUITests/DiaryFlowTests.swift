import XCTest

final class DiaryFlowTests: XCTestCase {
    // scripts/test-ios.sh supplies a fresh Go server on this loopback address.
    func testCreateTripPersistsAndDayNavigationWorks() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-serverURL", "http://127.0.0.1:18080"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Пока нет поездок"].waitForExistence(timeout: 15))
        app.buttons["addTrip"].tap()
        let save = app.buttons["saveTrip"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        XCTAssertFalse(save.isEnabled)
        let amount = app.textFields["tripAmount"]
        amount.tap(); amount.typeText("2700")
        let commission = app.textFields["tripCommission"]
        commission.tap(); commission.typeText("405")
        app.buttons["dismissKeyboard"].tap()
        if !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let net = app.staticTexts["dayNet"]
        XCTAssertTrue(net.waitForExistence(timeout: 10))
        assertNet(net, equals: "2295₸")
        app.buttons["Следующий день"].tap()
        XCTAssertTrue(app.staticTexts["Пока нет поездок"].waitForExistence(timeout: 10))
        app.buttons["Предыдущий день"].tap()
        XCTAssertTrue(net.waitForExistence(timeout: 10))
        assertNet(net, equals: "2295₸")
        app.terminate(); app.launch()
        XCTAssertTrue(net.waitForExistence(timeout: 10))
        assertNet(net, equals: "2295₸")
    }
    private func assertNet(_ element: XCUIElement, equals expected: String) {
        let normalized = element.label.filter { !$0.isWhitespace }
        XCTAssertEqual(normalized, expected)
    }
}
