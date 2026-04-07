import XCTest
import UIKit
@testable import CookSavvy

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    private var analyticsService: MockAnalyticsService!
    private var detectionService: MockIngredientDetectionService!
    private var cameraScanTracker: MockCameraScanTracker!

    override func setUp() {
        super.setUp()
        analyticsService = MockAnalyticsService()
        detectionService = MockIngredientDetectionService()
        cameraScanTracker = MockCameraScanTracker()
    }

    override func tearDown() {
        analyticsService = nil
        detectionService = nil
        cameraScanTracker = nil
        super.tearDown()
    }

    func testNextPageFromSecondStaticPageAdvancesToCameraPage() {
        let viewModel = makeViewModel()

        viewModel.currentPage = 1
        viewModel.nextPage()

        XCTAssertEqual(viewModel.currentPage, 2)
        XCTAssertTrue(viewModel.isCameraPage)
    }

    func testTypeInsteadCompletesWithNoIngredients() {
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

    func testSkipTracksSkipAndCompletesWithNoIngredients() {
        var completedIngredients: [Ingredient]?
        let viewModel = makeViewModel { ingredients in
            completedIngredients = ingredients
        }

        viewModel.skip()

        XCTAssertEqual(completedIngredients, [])
        XCTAssertEqual(analyticsService.trackedEvents.map(\.0), [.onboardingSkipped])
    }

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

    func testPhotoCapturedNoIngredientsStillRecordsScanAttempt() async {
        detectionService.stubbedIngredients = []
        let viewModel = makeViewModel()

        viewModel.photoCaptured(UIImage())

        for _ in 0..<20 {
            await Task.yield()
        }

        XCTAssertEqual(cameraScanTracker.recordScanWithoutQuotaCallCount, 1)
    }

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
