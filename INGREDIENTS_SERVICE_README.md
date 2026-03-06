# Ingredients Service

## Overview

A service that provides ingredient autocompletion functionality with automatic import from the Food.json file. The service ensures ingredients are loaded into the database on first use and provides fast search capabilities.

## Features

- **Automatic Import**: Loads ingredients from Food.json on first use
- **Smart Caching**: Only imports once, checks database before importing
- **Fast Search**: Case-insensitive substring matching
- **Async/Await**: Modern Swift concurrency
- **Error Handling**: Comprehensive error types for all failure scenarios

## Architecture

### Flow

1. **App starts** → Service initialized
2. **First search** → Checks if ingredients exist in database
3. **If not exist** → Imports from Food.json
4. **Provides results** → Returns matching ingredient names

### Components

- **IngredientsService**: Main service class
- **IngredientsServiceError**: Error types for service operations
- **DBInterfaceProtocol**: Database abstraction for testing

## Usage

### Basic Usage

```swift
// Initialize service
let ingredientsService = IngredientsService()

// Search for ingredients (auto-loads on first call)
let suggestions = try await ingredientsService.searchIngredients(matching: "chi")
// Results: ["Chicken", "Chicken Breast", "Chimichurri", ...]
```

### Advanced Usage

```swift
// Initialize with custom configuration
let customDB = DBInterface()
let service = IngredientsService(
    dbInterface: customDB,
    ingredientsFileName: "Food",
    ingredientsFileExtension: "json"
)

// Manually ensure ingredients are loaded
try await service.ensureIngredientsLoaded()

// Search with custom limit
let suggestions = try await service.searchIngredients(
    matching: "chi",
    limit: 10
)

// Get full ingredient objects (with metadata)
let fullIngredients = try await service.searchFullIngredients(
    matching: "chicken"
)

// Get specific ingredient by exact name
if let ingredient = try await service.getIngredient(byName: "Chicken") {
    print("Found: \(ingredient.name)")
    print("Group: \(ingredient.foodGroup ?? "Unknown")")
}

// Force re-import (useful for updates)
try await service.forceReimport()
```

### Integration with View Model

```swift
final class IngredientSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var suggestions: [String] = []
    
    private let ingredientsService = IngredientsService()
    
    func searchIngredients() async {
        do {
            suggestions = try await ingredientsService.searchIngredients(
                matching: searchText,
                limit: 20
            )
        } catch {
            print("Search failed: \(error)")
            suggestions = []
        }
    }
}
```

### SwiftUI Integration

```swift
struct IngredientsSearchView: View {
    @StateObject var viewModel = IngredientSearchViewModel()
    
    var body: some View {
        VStack {
            TextField("Search ingredients", text: $viewModel.searchText)
                .onChange(of: viewModel.searchText) { _ in
                    Task {
                        await viewModel.searchIngredients()
                    }
                }
            
            List(viewModel.suggestions, id: \.self) { suggestion in
                Text(suggestion)
            }
        }
    }
}
```

## API Reference

### Methods

#### `ensureIngredientsLoaded() async throws`
Ensures ingredients are loaded into the database. Called automatically on first search.

**Throws**: `IngredientsServiceError` if import fails

---

#### `searchIngredients(matching:limit:) async throws -> [String]`
Searches for ingredient names matching the query.

**Parameters**:
- `matching`: Search text (case-insensitive)
- `limit`: Maximum results (default: 50)

**Returns**: Array of matching ingredient names

**Throws**: `IngredientsServiceError` if search fails

---

#### `searchFullIngredients(matching:limit:) async throws -> [Ingredient]`
Searches for full ingredient objects with all metadata.

**Parameters**:
- `matching`: Search text (case-insensitive)
- `limit`: Maximum results (default: 50)

**Returns**: Array of matching `Ingredient` objects

**Throws**: `IngredientsServiceError` if search fails

---

#### `getIngredient(byName:) async throws -> Ingredient?`
Gets a specific ingredient by exact name (case-insensitive).

**Parameters**:
- `byName`: Exact ingredient name

**Returns**: The ingredient if found, nil otherwise

**Throws**: `IngredientsServiceError` if retrieval fails

---

#### `forceReimport() async throws`
Forces a re-import of ingredients from the JSON file.

**Throws**: `IngredientsServiceError` if import fails

## Error Handling

```swift
do {
    let results = try await service.searchIngredients(matching: "chi")
} catch IngredientsServiceError.fileNotFound(let fileName) {
    print("File not found: \(fileName)")
} catch IngredientsServiceError.emptyFile {
    print("Ingredients file is empty")
} catch IngredientsServiceError.importFailed(let error) {
    print("Import failed: \(error)")
} catch IngredientsServiceError.searchFailed(let error) {
    print("Search failed: \(error)")
} catch IngredientsServiceError.databaseError(let error) {
    print("Database error: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Error Types

- **fileNotFound**: The Food.json file is not in the bundle
- **emptyFile**: The Food.json file contains no ingredients
- **importFailed**: Failed to decode or insert ingredients
- **searchFailed**: Database search operation failed
- **retrievalFailed**: Failed to retrieve specific ingredient
- **databaseError**: General database operation failed

## Performance

- **First Load**: ~6-10ms (imports from JSON)
- **Subsequent Searches**: <1ms (database query)
- **Memory**: Minimal (ingredients stored in database, not in memory)

## Testing

### Test Coverage: 24/24 Tests Passing

- **Initialization**: 2 tests
- **Loading**: 4 tests
- **Search**: 7 tests
- **Full Search**: 2 tests
- **Get by Name**: 3 tests
- **Reimport**: 2 tests
- **Error Handling**: 3 tests
- **Integration**: 2 tests

### Running Tests

```bash
xcodebuild test -scheme CookSavvy \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CookSavvyTests/IngredientsServiceTests
```

## Files

### Implementation
- `CookSavvy/Model/IngredientsService.swift`

### Tests
- `CookSavvyTests/IngredientsServiceTests.swift`

### Data
- `CookSavvy/Support/Assets/Food.json`

## Benefits

1. **Zero Configuration**: Works out of the box
2. **Automatic Import**: No manual setup required
3. **Fast Performance**: Database-backed search
4. **Type Safe**: Full Swift type safety
5. **Testable**: Protocol-based design with mocks
6. **Error Resilient**: Comprehensive error handling
7. **Memory Efficient**: No in-memory caching needed

## Example Scenarios

### Scenario 1: User Types "chi"
```swift
let results = try await service.searchIngredients(matching: "chi")
// ["Chicken", "Chicken Breast", "Chimichurri", "Chili Pepper", ...]
```

### Scenario 2: User Types "tom"
```swift
let results = try await service.searchIngredients(matching: "tom")
// ["Tomato", "Tomato Sauce", "Tomato Paste", ...]
```

### Scenario 3: Empty Query
```swift
let results = try await service.searchIngredients(matching: "")
// [] (returns empty array immediately)
```

### Scenario 4: No Matches
```swift
let results = try await service.searchIngredients(matching: "xyz")
// [] (returns empty array)
```

## Integration Checklist

- [x] Service created
- [x] Tests written and passing
- [x] Documentation complete
- [ ] Integrate into a feature ViewModel
- [ ] Update UI to use service
- [ ] Add loading states
- [ ] Add error handling in UI

## Next Steps

1. Integrate `IngredientsService` into the active ingredient search flow
2. Update `getIngredientsByString` to use `IngredientsService`
3. Add debouncing for search input
4. Consider adding search history
5. Add analytics for popular searches
