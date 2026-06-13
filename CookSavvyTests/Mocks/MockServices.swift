//
//  MockServices.swift
//  CookSavvyTests
//

import Foundation
import UIKit
@testable import CookSavvy

final class MockLogger: LoggerProtocol {
    private(set) var debugMessages: [String] = []
    private(set) var infoMessages: [String] = []
    private(set) var noticeMessages: [String] = []
    private(set) var warningMessages: [String] = []
    private(set) var errorMessages: [String] = []
    private(set) var faultMessages: [String] = []

    func debug(_ message: String) {
        debugMessages.append(message)
    }

    func info(_ message: String) {
        infoMessages.append(message)
    }

    func notice(_ message: String) {
        noticeMessages.append(message)
    }

    func warning(_ message: String) {
        warningMessages.append(message)
    }

    func error(_ message: String) {
        errorMessages.append(message)
    }

    func fault(_ message: String) {
        faultMessages.append(message)
    }
}

// MARK: - MockIdleTimerService

/// Records every idle-timer state change so tests can assert the keep-awake pairing
/// without depending on the real `UIApplication` flag.
@MainActor
final class MockIdleTimerService: IdleTimerServiceProtocol {
    private(set) var disabledStates: [Bool] = []
    var isIdleTimerDisabled: Bool { disabledStates.last ?? false }

    func setIdleTimerDisabled(_ disabled: Bool) {
        disabledStates.append(disabled)
    }
}

// MARK: - MockDatabaseInitService

final class MockDatabaseInitService: DatabaseInitializationServiceProtocol {
    var state: DatabaseInitializationState = .ready

    func startInitialization() {}

    func waitForIngredients() async {}

    func waitForRecipes() async {}

    func markReadyForTesting() {
        state = .ready
    }
}

// MARK: - MockIngredientsService

final class MockIngredientsService: IngredientsServiceProtocol {

    var stubbedSearchResults: [String] = []
    var stubbedFullSearchResults: [Ingredient] = []
    var stubbedIngredient: Ingredient? = nil
    var stubbedAllIngredients: [Ingredient] = []
    var stubbedCategories: [IngredientCategory] = IngredientCategory.allCases
    var shouldThrow: Error?

    func ensureIngredientsLoaded() async throws {
        if let error = shouldThrow { throw error }
    }

    func searchIngredients(matching query: String, limit: Int) async throws -> [String] {
        if let error = shouldThrow { throw error }
        return stubbedSearchResults
    }

    func searchFullIngredients(matching query: String, limit: Int) async throws -> [Ingredient] {
        if let error = shouldThrow { throw error }
        return stubbedFullSearchResults
    }

    func getIngredient(byName name: String) async throws -> Ingredient? {
        if let error = shouldThrow { throw error }
        return stubbedIngredient
    }

    func getAllIngredients(category: IngredientCategory?, limit: Int) async throws -> [Ingredient] {
        if let error = shouldThrow { throw error }
        return stubbedAllIngredients
    }

    func getCategories() async throws -> [IngredientCategory] {
        if let error = shouldThrow { throw error }
        return stubbedCategories
    }
}

// MARK: - MockRecipeService

final class MockRecipeService: RecipeServiceProtocol {

    var stubbedRecipes: [Recipe] = []
    var stubbedStoredRecipes: [Recipe] = []
    var stubbedAvailableSources: [RecipeSourceType] = [.offline]
    var shouldThrow: Error?
    var getRecipesCallCount = 0
    private(set) var requestedIngredients: [Ingredient] = []

    func getRecipes(for ingredients: [Ingredient], from sourceType: RecipeSourceType) async throws -> [Recipe] {
        if let error = shouldThrow { throw error }
        getRecipesCallCount += 1
        requestedIngredients = ingredients
        return stubbedRecipes
    }

    var stubbedHadSourceFailures = false

    func getRecipes(for ingredients: [Ingredient], from sourceTypes: Set<RecipeSourceType>) async throws -> (recipes: [Recipe], hadSourceFailures: Bool) {
        if let error = shouldThrow { throw error }
        getRecipesCallCount += 1
        requestedIngredients = ingredients
        return (stubbedRecipes, stubbedHadSourceFailures)
    }

    func isSourceAvailable(_ sourceType: RecipeSourceType) async -> Bool {
        true
    }

    func getAvailableSources() async -> [RecipeSourceType] {
        stubbedAvailableSources
    }

    func storeRecipes(_ recipes: [Recipe]) throws {
        if let error = shouldThrow { throw error }
    }

    func getStoredRecipes(for ingredients: [Ingredient]) throws -> [Recipe] {
        if let error = shouldThrow { throw error }
        return stubbedStoredRecipes
    }

    var stubbedAllRecipes: [Recipe] = []
    private(set) var getAllRecipesCallCount = 0

    func getAllRecipes(limit: Int) async throws -> [Recipe] {
        if let error = shouldThrow { throw error }
        getAllRecipesCallCount += 1
        return stubbedAllRecipes
    }
}

// MARK: - MockPantryService

final class MockPantryService: PantryServiceProtocol {

    var stubbedItems: [Ingredient] = []
    var shouldThrow: Error?
    var addError: Error?
    var removeError: Error?
    var getItemsDelayNanoseconds: UInt64 = 0
    var delayNanoseconds: UInt64 = 0
    private(set) var addCalls: [Ingredient] = []
    private(set) var removeCalls: [Ingredient] = []

    func getItems() async throws -> [Ingredient] {
        try await applyDelayIfNeeded(getItemsDelayNanoseconds)
        try await applyDelayIfNeeded()
        if let error = shouldThrow { throw error }
        return stubbedItems
    }

    func addItem(_ ingredient: Ingredient) async throws {
        try await applyDelayIfNeeded()
        if let error = addError { throw error }
        if let error = shouldThrow { throw error }
        addCalls.append(ingredient)
        if !stubbedItems.contains(where: { $0.name.caseInsensitiveCompare(ingredient.name) == .orderedSame }) {
            stubbedItems.append(ingredient)
        }
    }

    func removeItem(_ ingredient: Ingredient) async throws {
        try await applyDelayIfNeeded()
        if let error = removeError { throw error }
        if let error = shouldThrow { throw error }
        removeCalls.append(ingredient)
        stubbedItems.removeAll { $0.name.caseInsensitiveCompare(ingredient.name) == .orderedSame }
    }

    func contains(_ ingredient: Ingredient) async throws -> Bool {
        try await applyDelayIfNeeded()
        if let error = shouldThrow { throw error }
        return stubbedItems.contains { $0.name.caseInsensitiveCompare(ingredient.name) == .orderedSame }
    }

    private func applyDelayIfNeeded() async throws {
        try await applyDelayIfNeeded(delayNanoseconds)
    }

    private func applyDelayIfNeeded(_ nanoseconds: UInt64) async throws {
        guard nanoseconds > 0 else { return }
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

// MARK: - MockRecommendationService

final class MockRecommendationService: RecipeRecommendationServiceProtocol {

    var stubbedResult: (recipes: [Recipe], reason: String?) = ([], nil)
    var shouldThrow: Error?
    var getSuggestionsCallCount = 0

    func getSuggestions(limit: Int) async throws -> (recipes: [Recipe], reason: String?) {
        if let error = shouldThrow { throw error }
        getSuggestionsCallCount += 1
        return stubbedResult
    }
}

// MARK: - MockCameraScanTracker

final class MockCameraScanTracker: CameraScanTrackerProtocol {

    var stubbedCanScan: Bool = true
    var stubbedRemainingScans: Int = CameraScanTracker.freeWeeklyLimit
    var recordScanCallCount = 0
    var recordScanWithoutQuotaCallCount = 0

    func canScan(limit: Int) -> Bool {
        stubbedCanScan
    }

    func recordScan() {
        recordScanCallCount += 1
    }

    func recordScanWithoutQuota() {
        recordScanWithoutQuotaCallCount += 1
    }

    func remainingScans(limit: Int) -> Int {
        stubbedRemainingScans
    }

    func totalScansRecorded() -> Int {
        recordScanCallCount + recordScanWithoutQuotaCallCount
    }
}

// MARK: - MockIngredientDetectionService

final class MockIngredientDetectionService: IngredientDetectionServiceProtocol {

    var stubbedIngredients: [Ingredient] = []
    var shouldThrow: Error?
    var delayNanoseconds: UInt64 = 0
    private(set) var detectIngredientsCallCount = 0

    func detectIngredients(in image: UIImage) async throws -> [Ingredient] {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let shouldThrow {
            throw shouldThrow
        }
        detectIngredientsCallCount += 1
        return stubbedIngredients
    }
}

// MARK: - MockCuratedCollectionService

final class MockCuratedCollectionService: CuratedCollectionServiceProtocol {
    var stubbedCollections: [CuratedCollection] = []
    var stubbedRecipes: [Recipe] = []

    func getCollectionsForThisWeek(isPremium: Bool) -> [CuratedCollection] {
        stubbedCollections
    }

    func getRecipes(for collection: CuratedCollection) async throws -> [Recipe] {
        stubbedRecipes
    }
}

// MARK: - MockImageService

final class MockImageService: ImageServiceProtocol {

    var memoryCacheCount: Int = 0
    var stubbedRecipeImage: UIImage?
    var stubbedNamedImages: [String: UIImage] = [:]
    var shouldThrowRecipeImage = false
    var loadRecipeImageCallCount = 0
    var loadNamedImageCalls: [String] = []

    func loadImage(for recipe: Recipe) async throws -> UIImage? {
        loadRecipeImageCallCount += 1
        if shouldThrowRecipeImage {
            throw MockServiceError.requestedFailure
        }
        return stubbedRecipeImage
    }
    func loadImage(for ingredient: Ingredient) async throws -> UIImage? { nil }
    func loadImage(named fileName: String) async throws -> UIImage? {
        loadNamedImageCalls.append(fileName)
        return stubbedNamedImages[fileName]
    }
    func loadImages(for recipes: [Recipe]) async throws -> [String: UIImage] { [:] }
    func prefetchImages(for recipes: [Recipe]) async {}
    func clearCache() {}
    func clearDiskCache(fileName: String?) throws {}
    func imageExists(named fileName: String) -> Bool { false }
}

enum MockServiceError: Error {
    case requestedFailure
}
