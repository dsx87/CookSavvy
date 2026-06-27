import XCTest
import UIKit
@testable import CookSavvy

final class OnboardingViewModelTests: XCTestCase {

    private var analyticsService: MockAnalyticsService!
    private var detectionService: MockIngredientDetectionService!
    private var cameraScanTracker: MockCameraScanTracker!

    @MainActor
    override func setUp() async throws {
        analyticsService = MockAnalyticsService()
        detectionService = MockIngredientDetectionService()
        cameraScanTracker = MockCameraScanTracker()
    }

    @MainActor
    override func tearDown() async throws {
        analyticsService = nil
        detectionService = nil
        cameraScanTracker = nil
    }

    @MainActor
    func testNextPageFromSecondStaticPageAdvancesToCameraPage() async {
        let viewModel = makeViewModel()

        viewModel.currentPage = 1
        viewModel.nextPage()

        XCTAssertEqual(viewModel.currentPage, 2)
        XCTAssertTrue(viewModel.isCameraPage)
    }

    @MainActor
    func testPrimaryButtonTitleUsesNextForStaticPages() async {
        let viewModel = makeViewModel()

        viewModel.currentPage = 0
        XCTAssertEqual(viewModel.primaryButtonTitle, Strings.Onboarding.next)

        viewModel.currentPage = 1
        XCTAssertEqual(viewModel.primaryButtonTitle, Strings.Onboarding.next)
    }

    @MainActor
    func testPrimaryButtonTitleUsesGetStartedForCameraPage() async {
        let viewModel = makeViewModel()

        viewModel.currentPage = viewModel.pages.count

        XCTAssertEqual(viewModel.primaryButtonTitle, Strings.Onboarding.getStarted)
    }

    @MainActor
    func testTypeInsteadCompletesWithNoIngredients() async {
        var completedIngredients: [Ingredient]?
        let viewModel = makeViewModel { ingredients in
            completedIngredients = ingredients
        }

        viewModel.typeInstead()

        XCTAssertEqual(completedIngredients, [])
        XCTAssertEqual(
            analyticsService.trackedEvents.map(\.0),
            [.onboardingTypeInsteadTapped, .onboardingCompleted]
        )
    }

    @MainActor
    func testPhotoCapturedCompletesWithDetectedIngredients() async {
        let expectedIngredients = [Ingredient(name: "Tomato"), Ingredient(name: "Basil")]
        detectionService.stubbedIngredients = expectedIngredients
        var completedIngredients: [Ingredient]?
        let viewModel = makeViewModel { ingredients in
            completedIngredients = ingredients
        }

        viewModel.photoCaptured(UIImage())

        for _ in 0..<20 {
            await Task.yield()
        }

        XCTAssertEqual(completedIngredients, expectedIngredients)
        XCTAssertEqual(cameraScanTracker.recordScanWithoutQuotaCallCount, 1)
        XCTAssertEqual(
            analyticsService.trackedEvents.map(\.0),
            [.onboardingCameraScanCompleted, .onboardingCompleted]
        )
    }

    @MainActor
    func testSkipTracksSkipAndCompletesWithNoIngredients() async {
        var completedIngredients: [Ingredient]?
        let viewModel = makeViewModel { ingredients in
            completedIngredients = ingredients
        }

        viewModel.skip()

        XCTAssertEqual(completedIngredients, [])
        XCTAssertEqual(analyticsService.trackedEvents.map(\.0), [.onboardingSkipped])
    }

    @MainActor
    func testPhotoCapturedDoesNotConsumeQuotaBasedScan() async {
        detectionService.stubbedIngredients = [Ingredient(name: "Eggs")]
        let viewModel = makeViewModel()

        viewModel.photoCaptured(UIImage())

        for _ in 0..<20 {
            await Task.yield()
        }

        XCTAssertEqual(cameraScanTracker.recordScanCallCount, 0)
        XCTAssertEqual(cameraScanTracker.recordScanWithoutQuotaCallCount, 1)
    }

    @MainActor
    func testTypeInsteadDuringProcessingIgnoresLateDetectionResult() async {
        detectionService.stubbedIngredients = [Ingredient(name: "Eggs")]
        detectionService.delayNanoseconds = 50_000_000
        var completedIngredients: [Ingredient]?
        let viewModel = makeViewModel { ingredients in
            completedIngredients = ingredients
        }

        viewModel.photoCaptured(UIImage())
        viewModel.typeInstead()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(completedIngredients, [])
        XCTAssertEqual(cameraScanTracker.recordScanWithoutQuotaCallCount, 1)
        XCTAssertEqual(
            analyticsService.trackedEvents.map(\.0),
            [.onboardingTypeInsteadTapped, .onboardingCompleted]
        )
    }

    @MainActor
    func testPhotoCapturedNoIngredientsStillRecordsScanAttempt() async {
        detectionService.stubbedIngredients = []
        let viewModel = makeViewModel()

        viewModel.photoCaptured(UIImage())

        for _ in 0..<20 {
            await Task.yield()
        }

        XCTAssertEqual(cameraScanTracker.recordScanWithoutQuotaCallCount, 1)
    }

    @MainActor
    private func makeViewModel(
        onComplete: @escaping ([Ingredient]) -> Void = { _ in }
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            analyticsService: analyticsService,
            ingredientDetectionService: detectionService,
            cameraScanTracker: cameraScanTracker,
            completionDelayNanoseconds: 0,
            onComplete: onComplete
        )
    }
}
