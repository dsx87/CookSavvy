import SwiftUI

private enum CreateRecipeViewModelConstants {
    static let defaultEmoji = "🍕"
    static let defaultCookTimeMinutes = 30
    static let defaultServings = 2
}

@MainActor
final class CreateRecipeViewModel: ObservableObject {

    struct StepRow: Identifiable, Hashable {
        let id = UUID()
        var text: String
        var timerMinutes: Int?
    }

    enum WizardStep: Int, CaseIterable {
        case nameAndPhoto = 0
        case ingredients = 1
        case steps = 2
        case details = 3
        case review = 4

        var title: String {
            switch self {
            case .nameAndPhoto: return Strings.CreateRecipe.nameYourRecipe
            case .ingredients: return Strings.CreateRecipe.addIngredients
            case .steps: return Strings.CreateRecipe.addSteps
            case .details: return Strings.CreateRecipe.details
            case .review: return Strings.CreateRecipe.reviewAndSave
            }
        }
    }

    static let foodEmojis: [String] = [
        "🍕", "🍔", "🌮", "🌯", "🥙", "🧆", "🥗", "🥘",
        "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🍤",
        "🍗", "🍖", "🥩", "🥓", "🧀", "🥚", "🍳", "🥞",
        "🧇", "🥐", "🍞", "🥖", "🥨", "🧁", "🍰", "🎂",
        "🍩", "🍪", "🍫", "🍿", "🥜", "🍯", "🥑", "🍅",
        "🥕", "🌽", "🥦", "🍆", "🫑", "🍄", "🥥", "🍋"
    ]

    // MARK: - Published State

    @Published var currentStep: WizardStep = .nameAndPhoto
    @Published var recipeName: String = ""
    @Published var selectedEmoji: String = CreateRecipeViewModelConstants.defaultEmoji
    @Published var tagline: String = ""
    @Published var ingredientRows: [String] = [""]
    @Published var stepRows: [StepRow] = [StepRow(text: "")]
    @Published var cookTimeMinutes: Int = CreateRecipeViewModelConstants.defaultCookTimeMinutes
    @Published var servings: Int = CreateRecipeViewModelConstants.defaultServings
    @Published var difficulty: String = Strings.CreateRecipe.difficultyEasy
    @Published var cuisine: String = ""
    @Published var isSaving: Bool = false
    @Published var saveError: String?
    @Published var didSave: Bool = false

    // MARK: - Dependencies

    private let userDataService: UserDataServiceProtocol
    private let onDismiss: () -> Void

    static let difficulties = [
        Strings.CreateRecipe.difficultyEasy,
        Strings.CreateRecipe.difficultyMedium,
        Strings.CreateRecipe.difficultyHard
    ]

    // MARK: - Init

    init(userDataService: UserDataServiceProtocol, onDismiss: @escaping () -> Void) {
        self.userDataService = userDataService
        self.onDismiss = onDismiss
    }

    // MARK: - Validation

    var isCurrentStepValid: Bool {
        switch currentStep {
        case .nameAndPhoto:
            return !recipeName.trimmingCharacters(in: .whitespaces).isEmpty
        case .ingredients:
            return ingredientRows.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        case .steps:
            return stepRows.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        case .details:
            return true
        case .review:
            return true
        }
    }

    var canGoBack: Bool {
        currentStep.rawValue > 0
    }

    var canGoForward: Bool {
        currentStep.rawValue < WizardStep.allCases.count - 1 && isCurrentStepValid
    }

    var isLastStep: Bool {
        currentStep == .review
    }

    var progress: Double {
        Double(currentStep.rawValue + 1) / Double(WizardStep.allCases.count)
    }

    // MARK: - Navigation

    func goNext() {
        guard canGoForward else { return }
        if let next = WizardStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    func goBack() {
        guard canGoBack else { return }
        if let prev = WizardStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }

    // MARK: - Ingredient Row Management

    func addIngredientRow() {
        ingredientRows.append("")
    }

    func removeIngredientRow(at index: Int) {
        guard ingredientRows.count > 1 else { return }
        ingredientRows.remove(at: index)
    }

    // MARK: - Step Row Management

    func addStepRow() {
        stepRows.append(StepRow(text: ""))
    }

    func removeStepRow(at index: Int) {
        guard stepRows.count > 1 else { return }
        stepRows.remove(at: index)
    }

    // MARK: - Filtered Data

    var validIngredients: [String] {
        ingredientRows
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var validSteps: [StepRow] {
        stepRows.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - Save

    func saveRecipe() {
        guard isCurrentStepValid else { return }
        isSaving = true
        saveError = nil

        Task {
            do {
                let recipe = buildRecipe()
                try await userDataService.saveUserRecipe(recipe)
                didSave = true
                onDismiss()
            } catch {
                saveError = error.localizedDescription
            }
            isSaving = false
        }
    }

    func dismiss() {
        onDismiss()
    }

    // MARK: - Private

    private func buildRecipe() -> Recipe {
        let instructions = validSteps.map { row in
            Recipe.Step(text: row.text.trimmingCharacters(in: .whitespaces), timerMinutes: row.timerMinutes)
        }
        let ingredients = validIngredients.map { Ingredient(name: $0) }
        let timeString = String(format: Strings.Common.minutesShort, Int64(cookTimeMinutes))
        let additionalInfo = Recipe.AdditionalInfo(
            time: timeString,
            servings: servings,
            complexity: difficulty,
            calories: nil
        )

        return Recipe(
            title: recipeName.trimmingCharacters(in: .whitespaces),
            ingredients: ingredients,
            instructions: instructions,
            image: "",
            cleanedIngredients: ingredients,
            additionalInfo: additionalInfo,
            tagline: tagline.isEmpty ? nil : tagline.trimmingCharacters(in: .whitespaces),
            isUserCreated: true,
            emoji: selectedEmoji,
            cuisine: cuisine.isEmpty ? nil : cuisine.trimmingCharacters(in: .whitespaces)
        )
    }
}
