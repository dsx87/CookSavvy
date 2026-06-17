import SwiftUI

/// Default values used to bootstrap a new create-recipe form.
private enum CreateRecipeViewModelConstants {
    static let defaultEmoji = "🍕"
    static let defaultCookTimeMinutes = 30
    static let defaultServings = 2
}

/// ViewModel backing the Create Recipe 5-step wizard.
///
/// Manages all mutable form state as the user progresses through:
/// 1. Name & Photo (emoji picker, title, tagline)
/// 2. Ingredients (dynamic text rows)
/// 3. Steps (dynamic step rows with optional per-step timers)
/// 4. Details (cook time, servings, difficulty, cuisine)
/// 5. Review & Save
///
/// Validates each step before allowing forward navigation, builds the final `Recipe` model,
/// persists it via `UserDataService`, and calls `onDismiss` on completion.
@Observable final class CreateRecipeViewModel {

    /// A mutable row in the steps list, combining instruction text and an optional step timer.
    struct StepRow: Identifiable, Hashable {
        let id = UUID()
        var text: String
        var timerMinutes: Int?
    }

    /// The five sequential screens of the create recipe wizard.
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

    // MARK: - Observable State

    /// The wizard page currently displayed.
    var currentStep: WizardStep = .nameAndPhoto
    /// User-entered recipe title.
    var recipeName: String = ""
    /// Emoji chosen from the picker as the recipe's cover image fallback.
    var selectedEmoji: String = CreateRecipeViewModelConstants.defaultEmoji
    /// Optional one-line description of the recipe.
    var tagline: String = ""
    /// Dynamic list of ingredient text fields; always has at least one empty row.
    var ingredientRows: [String] = [""]
    /// Dynamic list of step rows; always has at least one empty row.
    var stepRows: [StepRow] = [StepRow(text: "")]
    /// Total cook time in minutes (used to populate `AdditionalInfo`).
    var cookTimeMinutes: Int = CreateRecipeViewModelConstants.defaultCookTimeMinutes
    /// Number of servings the recipe makes.
    var servings: Int = CreateRecipeViewModelConstants.defaultServings
    /// Selected difficulty string from `difficulties`.
    var difficulty: String = Strings.CreateRecipe.difficultyEasy
    /// Optional cuisine type (free-text field).
    var cuisine: String = ""
    /// `true` while the save operation is in flight.
    var isSaving: Bool = false
    /// Non-`nil` when saving failed; drives the error alert.
    var saveError: String?
    /// Set to `true` after the recipe is successfully saved.
    var didSave: Bool = false

    // MARK: - Dependencies

    private let userDataService: UserDataServiceProtocol
    private let onDismiss: () -> Void

    static let difficulties = [
        Strings.CreateRecipe.difficultyEasy,
        Strings.CreateRecipe.difficultyMedium,
        Strings.CreateRecipe.difficultyHard
    ]

    // MARK: - Init

    /// Creates the view model with persistence dependency and dismissal callback.
    init(userDataService: UserDataServiceProtocol, onDismiss: @escaping () -> Void) {
        self.userDataService = userDataService
        self.onDismiss = onDismiss
    }

    // MARK: - Validation

    /// `true` when the current wizard step has satisfied its minimum input requirements.
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

    /// `true` when the user can navigate backwards to the previous step.
    var canGoBack: Bool {
        currentStep.rawValue > 0
    }

    /// `true` when the user can advance to the next step (step is valid and not the last).
    var canGoForward: Bool {
        currentStep.rawValue < WizardStep.allCases.count - 1 && isCurrentStepValid
    }

    /// `true` when the user is on the final Review & Save step.
    var isLastStep: Bool {
        currentStep == .review
    }

    /// Fractional wizard progress (0.0 – 1.0), used to drive the progress bar.
    var progress: Double {
        Double(currentStep.rawValue + 1) / Double(WizardStep.allCases.count)
    }

    // MARK: - Navigation

    /// Advances to the next wizard step if validation passes.
    func goNext() {
        guard canGoForward else { return }
        if let next = WizardStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    /// Returns to the previous wizard step.
    func goBack() {
        guard canGoBack else { return }
        if let prev = WizardStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }

    // MARK: - Ingredient Row Management

    /// Appends an empty ingredient text field.
    func addIngredientRow() {
        ingredientRows.append("")
    }

    /// Removes the ingredient row at `index`, keeping at least one row.
    func removeIngredientRow(at index: Int) {
        guard ingredientRows.count > 1 else { return }
        ingredientRows.remove(at: index)
    }

    // MARK: - Step Row Management

    /// Appends an empty step row.
    func addStepRow() {
        stepRows.append(StepRow(text: ""))
    }

    /// Removes the step row at `index`, keeping at least one row.
    func removeStepRow(at index: Int) {
        guard stepRows.count > 1 else { return }
        stepRows.remove(at: index)
    }

    // MARK: - Filtered Data

    /// Non-empty, trimmed ingredient strings ready to be persisted.
    var validIngredients: [String] {
        ingredientRows
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Non-empty step rows ready to be persisted.
    var validSteps: [StepRow] {
        stepRows.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - Save

    /// Builds the `Recipe` model from the current form state and persists it via `UserDataService`.
    /// Sets `didSave` on success or `saveError` on failure.
    func saveRecipe() {
        // `!isSaving` guards against a double-tap starting a second save (duplicate recipes).
        guard isCurrentStepValid, !isSaving else { return }
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

    /// Cancels the wizard without saving.
    func dismiss() {
        onDismiss()
    }

    /// Clears the save error, dismissing the alert.
    func dismissError() {
        saveError = nil
    }

    // MARK: - Private

    /// Assembles the `Recipe` model from validated form fields.
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
            additionalInfo: additionalInfo,
            tagline: tagline.isEmpty ? nil : tagline.trimmingCharacters(in: .whitespaces),
            isUserCreated: true,
            emoji: selectedEmoji,
            cuisine: cuisine.isEmpty ? nil : cuisine.trimmingCharacters(in: .whitespaces)
        )
    }
}
