//
//  CookModeViewModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class CookModeViewModelTests: XCTestCase {

    var mockUserDataService: MockUserDataService!
    var mockIdleTimerService: MockIdleTimerService!
    var dismissCallCount = 0

    @MainActor
    override func setUp() async throws {
        mockUserDataService = MockUserDataService()
        mockIdleTimerService = MockIdleTimerService()
        dismissCallCount = 0
    }

    @MainActor
    override func tearDown() async throws {
        mockUserDataService = nil
        mockIdleTimerService = nil
    }

    @MainActor
    private func makeRecipe(stepCount: Int) -> Recipe {
        let steps = (1...max(1, stepCount)).map { i in
            Recipe.Step(text: "Step \(i)", timerMinutes: i == 2 ? 5 : nil)
        }
        return Recipe(
            title: "Test Recipe",
            ingredients: [Ingredient(name: "Egg")],
            instructions: steps,
            image: "",
            additionalInfo: .empty
        )
    }

    @MainActor
    private func makeViewModel(stepCount: Int = 3) -> CookModeViewModel {
        CookModeViewModel(
            recipe: makeRecipe(stepCount: stepCount),
            userDataService: mockUserDataService,
            analyticsService: MockAnalyticsService(),
            logger: MockLogger(),
            idleTimerService: mockIdleTimerService,
            onDismiss: { [weak self] in self?.dismissCallCount += 1 }
        )
    }

    @MainActor
    func testInitialState() async {
        let vm = makeViewModel()
        XCTAssertEqual(vm.currentStep, 0)
        XCTAssertFalse(vm.timerRunning)
        XCTAssertEqual(vm.completedSteps.count, 0)
        XCTAssertFalse(vm.showFeedback)
    }

    @MainActor
    func testBeginAndEndKeepingScreenAwakeTogglesIdleTimer() async {
        let vm = makeViewModel()

        vm.beginKeepingScreenAwake()
        XCTAssertTrue(mockIdleTimerService.isIdleTimerDisabled)

        vm.endKeepingScreenAwake()
        XCTAssertFalse(mockIdleTimerService.isIdleTimerDisabled)
        XCTAssertEqual(mockIdleTimerService.disabledStates, [true, false])
    }

    @MainActor
    func testGoNextAdvancesStep() async {
        let vm = makeViewModel()
        vm.goNext()
        XCTAssertEqual(vm.currentStep, 1)
    }

    @MainActor
    func testGoPreviousFromZeroStays() async {
        let vm = makeViewModel()
        vm.goPrevious()
        XCTAssertEqual(vm.currentStep, 0)
    }

    @MainActor
    func testGoNextAtLastStepStays() async {
        let vm = makeViewModel(stepCount: 2)
        vm.goNext() // to step 1 (last)
        vm.goNext() // should stay at 1
        XCTAssertEqual(vm.currentStep, 1)
    }

    @MainActor
    func testProgressCalculation() async {
        let vm = makeViewModel(stepCount: 4)
        XCTAssertEqual(vm.progress, 0.0)

        vm.markDone() // completes step 0, advances to 1
        XCTAssertEqual(vm.progress, 0.25, accuracy: 0.001)

        vm.markDone() // completes step 1, advances to 2
        XCTAssertEqual(vm.progress, 0.5, accuracy: 0.001)
    }

    @MainActor
    func testFinishShowsFeedback() async {
        let vm = makeViewModel()
        XCTAssertFalse(vm.showFeedback)
        vm.finish()
        XCTAssertTrue(vm.showFeedback)
    }

    @MainActor
    func testSubmitFeedbackCallsServiceAndDismisses() async {
        let vm = makeViewModel()
        vm.finish()
        vm.feedbackRating = 4
        vm.submitFeedback()

        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(dismissCallCount, 1)
        XCTAssertEqual(mockUserDataService.markAsCookedCalls.count, 1)
        XCTAssertEqual(mockUserDataService.markAsCookedCalls.first?.rating, 4)
    }

    @MainActor
    func testSkipFeedbackCallsServiceAndDismisses() async {
        let vm = makeViewModel()
        vm.finish()
        vm.skipFeedback()

        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(dismissCallCount, 1)
        XCTAssertEqual(mockUserDataService.markAsCookedCalls.count, 1)
        XCTAssertNil(mockUserDataService.markAsCookedCalls.first?.rating)
    }

    @MainActor
    func testTimerResetOnStepChange() async {
        // makeRecipe gives step index 1 a 5-min timer
        let vm = makeViewModel(stepCount: 3)
        vm.goNext() // to step 1
        vm.toggleTimer() // start timer
        XCTAssertTrue(vm.timerRunning)

        vm.goNext() // to step 2, should reset timer
        XCTAssertFalse(vm.timerRunning)
        XCTAssertEqual(vm.timerSeconds, 0)
    }

    @MainActor
    func testDismissStopsTimerAndCallsOnDismiss() async {
        let vm = makeViewModel()
        vm.toggleTimer() // start timer regardless of step
        XCTAssertTrue(vm.timerRunning)

        vm.dismiss()

        XCTAssertFalse(vm.timerRunning)
        XCTAssertEqual(dismissCallCount, 1)
    }

    @MainActor
    func testSubmitFeedbackStillDismissesWhenSaveFails() async {
        mockUserDataService.shouldThrow = TestError.stub
        let vm = makeViewModel()
        vm.finish()
        vm.submitFeedback()

        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(dismissCallCount, 1)
        XCTAssertTrue(mockUserDataService.markAsCookedCalls.isEmpty)
    }

    @MainActor
    func testSkipFeedbackStillDismissesWhenSaveFails() async {
        mockUserDataService.shouldThrow = TestError.stub
        let vm = makeViewModel()
        vm.finish()
        vm.skipFeedback()

        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(dismissCallCount, 1)
        XCTAssertTrue(mockUserDataService.markAsCookedCalls.isEmpty)
    }
}

private enum TestError: Error {
    case stub
}
