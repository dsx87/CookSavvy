import XCTest

final class CameraScanUITests: FreeUserUITest {
    func testScanLimitBadgeVisible() {
        XCTAssertTrue(app.waitForElement(app.buttons[AccessibilityID.Discover.cameraButton], timeout: 5))
        XCTAssertTrue(app.waitForElement(app.staticTexts[AccessibilityID.Camera.scanLimitBadge], timeout: 5))
    }
}
