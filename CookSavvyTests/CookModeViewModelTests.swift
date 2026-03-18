//
//  CookModeViewModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

@MainActor
final class CookModeViewModelTests: XCTestCase {

    var mockUserDataService: MockUserDataService!
    var dismissCallCount = 0

    override func setUp() {
        super.setUp()
        mockUserDataService = MockUserDataService()
        dismissCallCount = 0
    }

    override func tearDown() {
        mockUserDataService = nil
        super.tearDown()
    }

    private func makeRecipe(stepCount: Int) -> Recipe {
        let steps = (1...max(1, stepCount)).map { i in
            Recipe.Step(text: "Step \(i)", timerMinutes: i == 2 ? 5 : nil)
        }
        return Recipe(
            title: "Test Recipe",
            ingredients: [Ingredient(name: "Egg")],
            instructions: steps,
            image: "",
            cleanedIngredients: [Ingredient(name: "Egg")],
            additionalInfo: .empty
        )
    }

    private func makeViewModel(stepCount: Int = 3) -> CookModeViewModel {
        CookModeViewModel(
            recipe: makeRecipe(stepCount: stepCount),
            userDataService: mockUserDataService,
            analyticsService: MockAnalyticsService(),
            onDismiss: { [weak self] in self?.dismissCallCount += 1 }
        )
    }

    func testInitialState() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.currentStep, 0)
        XCTAssertFalse(vm.timerRunning)
        XCTAssertEqual(vm.completedSteps.count, 0)
        XCTAssertFalse(vm.showFeedback)
    }

    func testGoNextAdvancesStep() {
        let vm = makeViewModel()
        vm.goNext()
        XCTAssertEqual(vm.currentStep, 1)
    }

    func testGoPreviousFromZeroStays() {
        let vm = makeViewModel()
        vm.goPrevious()
        XCTAssertEqual(vm.currentStep, 0)
    }

    func testGoNextAtLastStepStays() {
        let vm = makeViewModel(stepCount: 2)
        vm.goNext() // to step 1 (last)
        vm.goNext() // should stay at 1
        XCTAssertEqual(vm.currentStep, 1)
    }

    func testProgressCalculation() {
        let vm = makeViewModel(stepCount: 4)
        XCTAssertEqual(vm.progress, 0.0)

        vm.markDone() // completes step 0, advances to 1
        XCTAssertEqual(vm.progress, 0.25, accuracy: 0.001)

        vm.markDone() // completes step 1, advances to 2
        XCTAssertEqual(vm.progress, 0.5, accuracy: 0.001)
    }

    func testFinishShowsFeedback() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.showFeedback)
        vm.finish()
        XCTAssertTrue(vm.showFeedback)
    }

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

    func testSkipFeedbackCallsServiceAndDismisses() async {
        let vm = makeViewModel()
        vm.finish()
        vm.skipFeedback()

        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(dismissCallCount, 1)
        XCTAssertEqual(mockUserDataService.markAsCookedCalls.count, 1)
        XCTAssertNil(mockUserDataService.markAsCookedCalls.first?.rating)
    }

    func testTimerResetOnStepChange() {
        // makeRecipe gives step index 1 a 5-min timer
        let vm = makeViewModel(stepCount: 3)
        vm.goNext() // to step 1
        vm.toggleTimer() // start timer
        XCTAssertTrue(vm.timerRunning)

        vm.goNext() // to step 2, should reset timer
        XCTAssertFalse(vm.timerRunning)
        XCTAssertEqual(vm.timerSeconds, 0)
    }

    func testDismissStopsTimerAndCallsOnDismiss() {
        let vm = makeViewModel()
        vm.toggleTimer() // start timer regardless of step
        XCTAssertTrue(vm.timerRunning)

        vm.dismiss()

        XCTAssertFalse(vm.timerRunning)
        XCTAssertEqual(dismissCallCount, 1)
    }
}
