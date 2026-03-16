import XCTest

class BaseUITest: XCTestCase {
    var app: XCUIApplication!

    var baseLaunchArguments: [String] {
        ["--uitesting", "--skip-onboarding"]
    }

    var additionalLaunchArguments: [String] {
        []
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        launchApp()
    }

    func launchApp(extraLaunchArguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = baseLaunchArguments + additionalLaunchArguments + extraLaunchArguments
        app.launch()
    }

    func relaunchApp(extraLaunchArguments: [String] = []) {
        app.terminate()
        launchApp(extraLaunchArguments: extraLaunchArguments)
    }
}

class PremiumUserUITest: BaseUITest {
    override var additionalLaunchArguments: [String] {
        ["--premium-user", "--with-cooking-history", "--with-favorites", "--with-shopping-items"]
    }
}

class FreeUserUITest: BaseUITest {
    override var additionalLaunchArguments: [String] {
        ["--with-cooking-history", "--with-favorites"]
    }
}

class FreshInstallUITest: BaseUITest {
    override var baseLaunchArguments: [String] {
        ["--uitesting", "--fresh-install"]
    }
}
