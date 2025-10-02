# Recipe Service Architecture

## Overview

A comprehensive recipe service system that provides recipes from multiple sources (offline, online, AI) with automatic database storage and flexible source management.

## Architecture

### Core Components

#### 1. **RecipeSource.swift**
- `RecipeSourceType`: Enum defining available sources (offline, online, AI)
- `RecipeSourceProtocol`: Protocol that all recipe sources must implement
- `RecipeSourceError`: Comprehensive error handling for recipe operations

#### 2. **OfflineRecipeSource.swift**
- Fetches recipes from the local database
- Always available
- Uses existing `DBInterface` for data access
- Fully implemented and tested

#### 3. **OnlineRecipeSource.swift**
- Placeholder for future online API integration
- Configurable with API endpoint and key
- Currently returns unavailable error
- Ready for implementation when online service is available

#### 4. **AIRecipeSource.swift**
- Placeholder for future AI-powered recipe generation
- Configurable with model endpoint and key
- Currently returns unavailable error
- Ready for implementation when AI service is available

#### 5. **RecipeService.swift**
- Main service coordinating all recipe operations
- Manages multiple recipe sources
- Handles source selection and switching
- Automatic recipe storage in database (configurable)
- Provides unified interface for recipe fetching

## Usage

### Basic Usage

```swift
// Initialize with default configuration
let recipeService = RecipeService()

// Fetch recipes using current source (offline by default)
let ingredients: [Ingredient] = ["Chicken", "Tomato"]
let recipes = try await recipeService.getRecipes(for: ingredients)
```

### Advanced Usage

```swift
// Initialize with custom configuration
let dbInterface = DBInterface()
let recipeService = RecipeService(
    dbInterface: dbInterface,
    shouldStoreRecipes: true  // Auto-store fetched recipes
)

// Check available sources
let availableSources = await recipeService.getAvailableSources()

// Switch to a different source
try await recipeService.setSource(.online)

// Fetch from specific source without switching
let recipes = try await recipeService.getRecipes(
    for: ingredients,
    from: .ai
)

// Manually store recipes
try recipeService.storeRecipes(recipes)

// Get stored recipes directly from database
let storedRecipes = try recipeService.getStoredRecipes(for: ingredients)
```

### Custom Source Implementation

```swift
// Create custom source
class CustomRecipeSource: RecipeSourceProtocol {
    var sourceType: RecipeSourceType { .online }
    
    func fetchRecipes(for ingredients: [Ingredient]) async throws -> [Recipe] {
        // Your implementation
    }
    
    func isAvailable() async -> Bool {
        // Your availability check
    }
}

// Use custom source
let customSource = CustomRecipeSource()
let sources: [RecipeSourceType: RecipeSourceProtocol] = [
    .offline: OfflineRecipeSource(),
    .online: customSource
]

let service = RecipeService(
    dbInterface: DBInterface(),
    sources: sources,
    defaultSource: .offline
)
```

## Flow

1. **User selects source** → `setSource(_:)`
2. **Service fetches recipes** → Source-specific implementation
3. **Recipes stored in DB** → Automatic (if enabled) or manual via `storeRecipes(_:)`
4. **Service provides recipes** → Returns fetched recipes

## Benefits & Improvements

### Implemented Benefits

1. **Separation of Concerns**: Each source is independent and testable
2. **Protocol-Oriented Design**: Easy to add new sources without modifying existing code
3. **Async/Await**: Modern Swift concurrency for better performance
4. **Comprehensive Error Handling**: Specific error types for different failure scenarios
5. **Flexible Storage**: Optional automatic storage with manual override capability
6. **Source Availability Checking**: Prevents errors by checking source status before use
7. **Type Safety**: Strong typing throughout with clear interfaces

### Future-Ready

- Online and AI sources are stubbed and ready for implementation
- No breaking changes needed when adding new sources
- Configuration-based approach for API keys and endpoints

## Testing

### Test Coverage

All components have comprehensive test coverage:

1. **RecipeSourceTests** (7 tests)
   - Source type validation
   - Error handling
   - Codable conformance

2. **OfflineRecipeSourceTests** (10 tests)
   - Fetch operations
   - Error scenarios
   - Performance testing
   - Edge cases

3. **RecipeServiceTests** (21 tests)
   - Source management
   - Recipe fetching
   - Storage operations
   - Integration workflows
   - Error propagation

4. **OnlineAndAIRecipeSourceTests** (8 tests)
   - Placeholder behavior
   - Unavailability handling
   - Configuration

### Test Results

```
✅ RecipeSourceTests: 7/7 passed
✅ OfflineRecipeSourceTests: 10/10 passed
✅ RecipeServiceTests: 21/21 passed
✅ OnlineRecipeSourceTests: 4/4 passed
✅ AIRecipeSourceTests: 4/4 passed

Total: 46/46 tests passed
```

## Files Created

### Model Files
- `CookSavvy/Model/RecipeSource.swift`
- `CookSavvy/Model/OfflineRecipeSource.swift`
- `CookSavvy/Model/OnlineRecipeSource.swift`
- `CookSavvy/Model/AIRecipeSource.swift`
- `CookSavvy/Model/RecipeService.swift`

### Test Files
- `CookSavvyTests/RecipeSourceTests.swift`
- `CookSavvyTests/OfflineRecipeSourceTests.swift`
- `CookSavvyTests/RecipeServiceTests.swift`
- `CookSavvyTests/OnlineAndAIRecipeSourceTests.swift`

## Integration with Existing Code

The service integrates seamlessly with existing components:

- Uses existing `DBInterface` for database operations
- Works with existing `Recipe` and `Ingredient` models
- No modifications to existing code required
- Can be integrated into `IngredientsInputViewModel` when ready

### Example Integration

```swift
final class IngredientsInputViewModel: ObservableObject {
    private let recipeService = RecipeService()
    
    func findRecipes() async {
        do {
            let recipes = try await recipeService.getRecipes(
                for: Array(selectedIngredients)
            )
            // Update UI with recipes
        } catch {
            // Handle error
        }
    }
}
```

## Error Handling

All operations throw descriptive errors:

```swift
do {
    let recipes = try await recipeService.getRecipes(for: ingredients)
} catch RecipeSourceError.sourceUnavailable(let type) {
    print("Source \(type.displayName) is unavailable")
} catch RecipeSourceError.noRecipesFound {
    print("No recipes found for these ingredients")
} catch RecipeSourceError.databaseError(let error) {
    print("Database error: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Next Steps

1. Implement `OnlineRecipeSource` when API is available
2. Implement `AIRecipeSource` when AI service is ready
3. Integrate into existing view models
4. Add UI for source selection
5. Consider caching strategies for online sources
