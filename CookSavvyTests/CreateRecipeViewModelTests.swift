//
//  CreateRecipeViewModelTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class CreateRecipeViewModelTests: XCTestCase {

    var mockUserDataService: MockUserDataService!
    var dismissCallCount = 0

    @MainActor
    override func setUp() async throws {
        mockUserDataService = MockUserDataService()
        dismissCallCount = 0
    }

    @MainActor
    override func tearDown() async throws {
        mockUserDataService = nil
    }

    @MainActor
    private func makeViewModel() -> CreateRecipeViewModel {
        CreateRecipeViewModel(
            userDataService: mockUserDataService,
            onDismiss: { [weak self] in self?.dismissCallCount += 1 }
        )
    }

    @MainActor
    func testInitialStep() async {
        let vm = makeViewModel()
        XCTAssertEqual(vm.currentStep, .nameAndPhoto)
    }

    @MainActor
    func testGoNextAdvancesStep() async {
        let vm = makeViewModel()
        vm.recipeName = "Pasta Carbonara"
        vm.goNext()
        XCTAssertEqual(vm.currentStep, .ingredients)
    }

    @MainActor
    func testBlockedWhenInvalid() async {
        let vm = makeViewModel()
        // Name is empty so nameAndPhoto step is invalid
        vm.recipeName = ""
        XCTAssertFalse(vm.isCurrentStepValid)
        vm.goNext()
        XCTAssertEqual(vm.currentStep, .nameAndPhoto)
    }

    @MainActor
    func testGoBackFromFirstStays() async {
        let vm = makeViewModel()
        vm.goBack()
        XCTAssertEqual(vm.currentStep, .nameAndPhoto)
    }

    @MainActor
    func testValidationPerStep() async {
        let vm = makeViewModel()

        // nameAndPhoto: valid only if name is non-empty
        vm.recipeName = ""
        XCTAssertFalse(vm.isCurrentStepValid)
        vm.recipeName = "Pizza"
        XCTAssertTrue(vm.isCurrentStepValid)

        // Navigate to ingredients
        vm.goNext()
        XCTAssertEqual(vm.currentStep, .ingredients)
        // ingredients: valid if at least one non-empty row
        vm.ingredientRows = [""]
        XCTAssertFalse(vm.isCurrentStepValid)
        vm.ingredientRows = ["Tomato"]
        XCTAssertTrue(vm.isCurrentStepValid)
    }

    @MainActor
    func testSaveCallsService() async {
        let vm = makeViewModel()
        vm.recipeName = "Egg Toast"
        vm.ingredientRows = ["Egg", "Bread"]
        vm.stepRows = [CreateRecipeViewModel.StepRow(text: "Toast bread")]

        // Navigate to review step
        vm.goNext() // to ingredients
        vm.goNext() // to steps
        vm.goNext() // to details
        vm.goNext() // to review

        vm.saveRecipe()

        // Yield to let the spawned Task complete on the MainActor
        for _ in 0..<10 { await Task.yield() }

        XCTAssertFalse(mockUserDataService.savedUserRecipes.isEmpty)
        XCTAssertEqual(mockUserDataService.savedUserRecipes.first?.title, "Egg Toast")
    }

    @MainActor
    func testDataPersistsAcrossSteps() async {
        let vm = makeViewModel()
        vm.recipeName = "Chicken Wrap"
        vm.ingredientRows = ["Chicken", "Lettuce"]

        vm.goNext() // to ingredients
        vm.goNext() // to steps (goes back to review)

        // Navigate back and verify data is intact
        vm.goBack()
        XCTAssertEqual(vm.ingredientRows, ["Chicken", "Lettuce"])

        vm.goBack()
        XCTAssertEqual(vm.recipeName, "Chicken Wrap")
    }

    @MainActor
    func testBlankIngredientRowsAreTrimmed() async {
        let vm = makeViewModel()
        vm.recipeName = "Soup"
        vm.ingredientRows = ["", "Potato", "  ", "Salt"]
        vm.stepRows = [CreateRecipeViewModel.StepRow(text: "Boil")]

        vm.goNext(); vm.goNext(); vm.goNext(); vm.goNext() // to review
        vm.saveRecipe()
        for _ in 0..<10 { await Task.yield() }

        let saved = mockUserDataService.savedUserRecipes.first
        XCTAssertEqual(saved?.ingredients.map(\.name), ["Potato", "Salt"])
    }

    @MainActor
    func testBlankStepRowsAreTrimmed() async {
        let vm = makeViewModel()
        vm.recipeName = "Salad"
        vm.ingredientRows = ["Lettuce"]
        vm.stepRows = [
            CreateRecipeViewModel.StepRow(text: "Chop"),
            CreateRecipeViewModel.StepRow(text: "   "),
            CreateRecipeViewModel.StepRow(text: "Dress")
        ]

        vm.goNext(); vm.goNext(); vm.goNext(); vm.goNext()
        vm.saveRecipe()
        for _ in 0..<10 { await Task.yield() }

        let saved = mockUserDataService.savedUserRecipes.first
        XCTAssertEqual(saved?.instructions.map(\.text), ["Chop", "Dress"])
    }

    @MainActor
    func testEmojiTaglineCuisineAreSaved() async {
        let vm = makeViewModel()
        vm.recipeName = "Tacos"
        vm.ingredientRows = ["Beef"]
        vm.stepRows = [CreateRecipeViewModel.StepRow(text: "Cook")]
        vm.selectedEmoji = "🌮"
        vm.tagline = "A bold favourite"
        vm.cuisine = "Mexican"

        vm.goNext(); vm.goNext(); vm.goNext(); vm.goNext()
        vm.saveRecipe()
        for _ in 0..<10 { await Task.yield() }

        let saved = mockUserDataService.savedUserRecipes.first
        XCTAssertEqual(saved?.emoji, "🌮")
        XCTAssertEqual(saved?.tagline, "A bold favourite")
        XCTAssertEqual(saved?.cuisine, "Mexican")
    }

    @MainActor
    func testSaveFailureSetsError() async {
        struct SaveError: Error, LocalizedError {
            var errorDescription: String? { "DB write failed" }
        }
        mockUserDataService.shouldThrow = SaveError()

        let vm = makeViewModel()
        vm.recipeName = "Omelette"
        vm.ingredientRows = ["Egg"]
        vm.stepRows = [CreateRecipeViewModel.StepRow(text: "Whisk")]

        vm.goNext(); vm.goNext(); vm.goNext(); vm.goNext()
        vm.saveRecipe()
        // Sleep to allow the spawned Task to hop off MainActor and back
        try? await Task.sleep(nanoseconds: 50_000_000)
        for _ in 0..<10 { await Task.yield() }

        XCTAssertNotNil(vm.saveError)
        XCTAssertFalse(vm.isSaving)
        XCTAssertFalse(vm.didSave)
        XCTAssertEqual(dismissCallCount, 0)
    }
}
