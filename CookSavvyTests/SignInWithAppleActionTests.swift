import XCTest
@testable import CookSavvy

@MainActor
final class SignInWithAppleActionTests: XCTestCase {

    private var authService: MockAuthService!
    private var analyticsService: MockAnalyticsService!
    private var appleSignInManager: MockAppleSignInManager!
    private var logger: MockLogger!

    override func setUp() {
        super.setUp()
        authService = MockAuthService(initialState: .signedIn(userId: "anon"), isAnonymous: true)
        analyticsService = MockAnalyticsService()
        appleSignInManager = MockAppleSignInManager()
        logger = MockLogger()
    }

    override func tearDown() {
        authService = nil
        analyticsService = nil
        appleSignInManager = nil
        logger = nil
        super.tearDown()
    }

    private func makeAction(
        appleSignInManager: any AppleSignInManaging
    ) -> SignInWithAppleAction {
        SignInWithAppleAction(
            authService: authService,
            analyticsService: analyticsService,
            logger: logger,
            appleSignInManager: appleSignInManager
        )
    }

    func testSignInCompletesThroughAuthAndAnalytics() async {
        let action = makeAction(appleSignInManager: appleSignInManager)

        let result = await action.signIn(context: .settings)

        XCTAssertEqual(result, .completed)
        XCTAssertFalse(action.isSigningIn)
        XCTAssertFalse(authService.isAnonymous)
        XCTAssertEqual(authService.signInWithAppleCallCount, 1)
        XCTAssertEqual(analyticsService.trackedEvents.map(\.0), [
            .signInWithAppleStarted,
            .signInWithAppleCompleted
        ])
    }

    func testSignInFailureTracksFailureAndReturnsErrorMessage() async {
        authService.signInWithAppleError = AuthError.signInFailed
        let action = makeAction(appleSignInManager: appleSignInManager)

        let result = await action.signIn(context: .settings)

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(result.errorMessage, Strings.Errors.actionFailed)
        XCTAssertFalse(action.isSigningIn)
        XCTAssertEqual(analyticsService.trackedEvents.map(\.0), [
            .signInWithAppleStarted,
            .signInWithAppleFailed
        ])
    }

    func testCancelledSignInDoesNotTrackFailure() async {
        appleSignInManager.error = AuthError.signInCancelled
        let action = makeAction(appleSignInManager: appleSignInManager)

        let result = await action.signIn(context: .settings)

        XCTAssertEqual(result, .cancelled)
        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(analyticsService.trackedEvents.map(\.0), [.signInWithAppleStarted])
    }

    func testConcurrentSignInIsIgnoredWhileFirstRequestIsActive() async {
        let delayedManager = DelayedAppleSignInManager()
        let action = makeAction(appleSignInManager: delayedManager)

        async let firstResult = action.signIn(context: .settings)
        await delayedManager.waitUntilStarted()
        let secondResult = await action.signIn(context: .settings)

        delayedManager.complete()
        let completedFirstResult = await firstResult

        XCTAssertEqual(secondResult, .alreadyInProgress)
        XCTAssertEqual(completedFirstResult, .completed)
        XCTAssertEqual(delayedManager.signInCallCount, 1)
        XCTAssertEqual(authService.signInWithAppleCallCount, 1)
    }
}

@MainActor
private final class DelayedAppleSignInManager: AppleSignInManaging {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var startContinuation: CheckedContinuation<Void, Never>?
    private(set) var signInCallCount = 0

    func signIn() async throws -> AppleSignInResult {
        signInCallCount += 1
        startContinuation?.resume()
        startContinuation = nil
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard signInCallCount == 0 else { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func complete() {
        continuation?.resume(
            returning: AppleSignInResult(
                identityToken: Data("token".utf8),
                nonce: "nonce",
                fullName: nil,
                email: nil
            )
        )
        continuation = nil
    }
}
