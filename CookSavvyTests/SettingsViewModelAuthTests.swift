//
//  SettingsViewModelAuthTests.swift
//  CookSavvyTests
//

import Combine
import XCTest
@testable import CookSavvy

@MainActor
final class SettingsViewModelAuthTests: XCTestCase {

    private var mockAuth: MockAuthService!
    private var mockAnalytics: MockAnalyticsService!
    private var sut: SettingsViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = []
        mockAuth = MockAuthService(initialState: .signedIn(userId: "anon-user"), isAnonymous: true)
        mockAnalytics = MockAnalyticsService()
        sut = try makeViewModel(authService: mockAuth)
    }

    override func tearDownWithError() throws {
        cancellables = nil
        sut = nil
        mockAuth = nil
        mockAnalytics = nil
        try super.tearDownWithError()
    }

    private func makeViewModel(authService: MockAuthService) throws -> SettingsViewModel {
        let db = try DBInterface(inMemory: true)
        return SettingsViewModel(
            userDataService: MockUserDataService(),
            dbInterface: db,
            subscriptionService: MockSubscriptionService(),
            dietaryPreferences: DietaryPreferences(),
            authService: authService,
            analyticsService: mockAnalytics,
            signInWithAppleAction: SignInWithAppleAction(
                authService: authService,
                analyticsService: mockAnalytics,
                logger: MockLogger(),
                appleSignInManager: MockAppleSignInManager()
            ),
            logger: MockLogger(),
            coordinator: nil
        )
    }

    // MARK: - Initial State

    func testInitialAnonymousState() {
        XCTAssertTrue(sut.isAnonymous)
        XCTAssertNotNil(sut.currentUserId)
    }

    func testInitialSignedInState() throws {
        let auth = MockAuthService(initialState: .signedIn(userId: "apple-user"), isAnonymous: false)
        let vm = try makeViewModel(authService: auth)
        XCTAssertFalse(vm.isAnonymous)
        XCTAssertEqual(vm.currentUserId, "apple-user")
    }

    // MARK: - Auth State Observation

    func testAuthStateUpdatesOnPublisherChange() {
        let expectation = expectation(description: "authState updates")

        sut.$authState
            .dropFirst()
            .sink { state in
                if case .signedIn(let id) = state, id == "new-user" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        mockAuth.setAuthState(.signedIn(userId: "new-user"))

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Sign Out

    func testSignOutCallsAuthService() async {
        await sut.signOut()
        XCTAssertEqual(mockAuth.signOutCallCount, 1)
        XCTAssertEqual(mockAuth.signInAnonymouslyCallCount, 1)
    }

    func testSignOutTracksAnalytics() async {
        await sut.signOut()
        let events = mockAnalytics.trackedEvents.map(\.0)
        XCTAssertTrue(events.contains(.signOutCompleted))
    }

    func testSignOutErrorShowsErrorMessage() async {
        mockAuth.signOutError = AuthError.signOutFailed
        await sut.signOut()
        XCTAssertNotNil(sut.errorMessage)
    }

    func testSignOutAnonymousFallbackFailureSurfaces() async {
        mockAuth.signInAnonymouslyError = AuthError.signInFailed
        await sut.signOut()
        // sign-out itself succeeded, analytics should fire
        let events = mockAnalytics.trackedEvents.map(\.0)
        XCTAssertTrue(events.contains(.signOutCompleted))
        // but the failed anonymous fallback should surface an error message
        XCTAssertNotNil(sut.errorMessage)
    }

    func testSignOutAnonymousFallbackSuccessNoError() async {
        await sut.signOut()
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - MockAuthService State Transitions

    func testMockStartSessionIfNeededTransitionsFromSignedOut() async {
        let auth = MockAuthService(initialState: .signedOut)
        await auth.startSessionIfNeeded()
        XCTAssertEqual(auth.startSessionIfNeededCallCount, 1)
        if case .signedIn = auth.authState {
            // expected
        } else {
            XCTFail("Expected signedIn state after startSessionIfNeeded from signedOut")
        }
    }

    func testMockSignInAnonymouslyFromSignedOut() async throws {
        let analytics = MockAnalyticsService()
        let auth = MockAuthService(initialState: .signedOut, analyticsService: analytics)
        try await auth.signInAnonymously()
        XCTAssertEqual(auth.signInAnonymouslyCallCount, 1)
        XCTAssertTrue(auth.isAnonymous)
        XCTAssertEqual(analytics.trackedEvents.map(\.0), [.anonymousAuthCompleted])
        if case .signedIn = auth.authState {
            // expected
        } else {
            XCTFail("Expected signedIn state after anonymous sign in")
        }
    }

    func testMockSignInWithAppleTransitions() async throws {
        let auth = MockAuthService(initialState: .signedIn(userId: "anon"), isAnonymous: true)
        try await auth.signInWithApple(identityToken: Data("token".utf8), nonce: "nonce")
        XCTAssertFalse(auth.isAnonymous)
        XCTAssertEqual(auth.signInWithAppleCallCount, 1)
    }

    func testMockSignOutReturnsToSignedOut() async throws {
        let auth = MockAuthService(initialState: .signedIn(userId: "user"), isAnonymous: false)
        try await auth.signOut()
        XCTAssertEqual(auth.authState, .signedOut)
        XCTAssertTrue(auth.isAnonymous)
    }

    func testMockSignInAnonymouslyError() async {
        let auth = MockAuthService(initialState: .signedOut)
        auth.signInAnonymouslyError = AuthError.signInFailed
        do {
            try await auth.signInAnonymously()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(auth.authState, .signedOut)
        }
    }
}
