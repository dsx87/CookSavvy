# CookSavvy Implementation Plan

## Current State Summary

The app has a foundation with:
- Models: `Recipe`, `Ingredient` (well-structured with Codable support)
- Database: GRDB-based SQLite with FTS5 search
- Services: `IngredientsService`, `RecipeService`, `ImageService`
- Views: `IngredientsInputView`, `RecipesResultView`, `RecipeDetailsView`, `SettingsView` (placeholder)
- Recipe source abstraction: `OfflineRecipeSource` works, `OnlineRecipeSource`/`AIRecipeSource` are stubs

---

## Identified Issues

### 1. Dependency Injection Problems
- `RecipesResultView` creates its own `DBInterface()`, `RecipeService()`, etc. in init
- Each view creates separate service instances instead of sharing
- No centralized dependency container
- Multiple `DBInterface` instances = multiple DB connections

### 2. MVVM Violations
- ViewModels defined in same file as Views (should be separate files)
- `TabContainerView` has no ViewModel
- Views create services directly in initializers
- Navigation logic embedded in views

### 3. Architecture Drift
- `RecipesResultViewModel.ensureRecipesImported()` contains data import logic that belongs in a service
- No app-level state management (recent items, user preferences)
- Mixed responsibilities in ViewModels

### 4. Code Quality
- 400+ lines of commented-out old SQLite implementation in `DBInterfaceProtocol.swift`
- Test-specific code (`ingredientVariants` tracking) in production DB class
- Hardcoded placeholder data in `TabContainerView`

### 5. Missing Features
- Recent ingredients (no persistence)
- Recent recipes (no persistence)
- Favorites system (not implemented)
- Settings (placeholder only)

---

## Target Architecture

```
CookSavvy/
├── App/
│   ├── CookSavvyApp.swift
│   └── AppContainer.swift          # Dependency container
├── Model/
│   ├── Entities/
│   │   ├── Recipe.swift
│   │   └── Ingredient.swift
│   ├── Database/
│   │   ├── DBInterfaceProtocol.swift
│   │   └── DBInterface.swift
│   └── Services/
│       ├── IngredientsService.swift
│       ├── RecipeService.swift
│       ├── ImageService.swift
│       ├── DataImportService.swift  # NEW: handles CSV/ZIP import
│       └── UserDataService.swift    # NEW: recent items, favorites
├── RecipeSources/
│   ├── RecipeSourceProtocol.swift
│   ├── OfflineRecipeSource.swift
│   ├── OnlineRecipeSource.swift     # stub for now
│   └── AIRecipeSource.swift         # stub for now
├── Views/
│   ├── IngredientsInput/
│   │   ├── IngredientsInputView.swift
│   │   ├── IngredientsInputViewModel.swift  # SEPARATE file
│   │   └── Components/...
│   ├── RecipesResult/
│   │   ├── RecipesResultView.swift
│   │   ├── RecipesResultViewModel.swift     # SEPARATE file
│   │   └── Components/...
│   ├── RecipeDetails/
│   │   ├── RecipeDetailsView.swift
│   │   ├── RecipeDetailsViewModel.swift     # NEW
│   │   └── Components/...
│   ├── RecentRecipes/
│   │   ├── RecentRecipesView.swift          # NEW
│   │   └── RecentRecipesViewModel.swift     # NEW
│   ├── Favorites/
│   │   ├── FavoritesView.swift              # NEW
│   │   └── FavoritesViewModel.swift         # NEW
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── SettingsViewModel.swift          # NEW
│   ├── TabContainer/
│   │   ├── TabContainerView.swift
│   │   └── TabContainerViewModel.swift      # NEW
│   └── Common/
│       ├── Colors.swift
│       ├── AsyncImageDisk.swift
│       └── DefaultPlaceholder.swift
└── Utilities/
    ├── CSVToJSONReader.swift
    ├── ImageExtractor.swift
    ├── Unarchiver.swift
    └── Extensions/
        ├── String+extensions.swift
        └── Character+extensions.swift
```

---

## Implementation Phases

### Phase 1: Foundation Cleanup (Priority: HIGH)

**Goal:** Fix architectural issues without changing functionality.

#### 1.1 Create Dependency Container
Create `AppContainer` to hold shared service instances:

```swift
// App/AppContainer.swift
@MainActor
final class AppContainer: ObservableObject {
    let dbInterface: DBInterfaceProtocol
    let ingredientsService: IngredientsService
    let recipeService: RecipeService
    let imageService: ImageService
    let dataImportService: DataImportService
    let userDataService: UserDataService

    init() {
        self.dbInterface = DBInterface()
        self.ingredientsService = IngredientsService(dbInterface: dbInterface)
        self.recipeService = RecipeService(dbInterface: dbInterface)
        self.imageService = ImageService()
        self.dataImportService = DataImportService(dbInterface: dbInterface)
        self.userDataService = UserDataService(dbInterface: dbInterface)
    }
}
```

Inject via `@EnvironmentObject` from `CookSavvyApp`.

#### 1.2 Separate ViewModels into Files
Move each ViewModel to its own file:
- `IngredientsInputViewModel.swift`
- `RecipesResultViewModel.swift`
- Create `TabContainerViewModel.swift`

#### 1.3 Clean Up DBInterface
- Remove commented-out old SQLite implementation (lines 442-837)
- Move `ingredientVariants` tracking to a test-only subclass or separate test helper
- Keep only production code in main class

#### 1.4 Create DataImportService
Extract import logic from `RecipesResultViewModel`:

```swift
// Model/Services/DataImportService.swift
final class DataImportService {
    private let dbInterface: DBInterfaceProtocol
    private let csvReader: CSVToJSONReader
    private var isRecipesImported: Bool = false

    func ensureRecipesImported() async throws { ... }
    func ensureIngredientsImported() async throws { ... }
}
```

---

### Phase 2: Database Schema Extension (Priority: HIGH)

**Goal:** Add persistence for recent items and favorites.

#### 2.1 Extend Database Schema
Add new tables to `DBInterface.createSchema()`:

```sql
-- Recent ingredients (for quick selection)
CREATE TABLE IF NOT EXISTS recent_ingredients (
    ingredient_name TEXT PRIMARY KEY,
    last_used_at INTEGER NOT NULL,
    use_count INTEGER DEFAULT 1,
    FOREIGN KEY(ingredient_name) REFERENCES ingredients(name) ON DELETE CASCADE
);

-- Recent recipe views
CREATE TABLE IF NOT EXISTS recent_recipes (
    recipe_id INTEGER PRIMARY KEY,
    last_viewed_at INTEGER NOT NULL,
    view_count INTEGER DEFAULT 1,
    FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
);

-- Favorite recipes
CREATE TABLE IF NOT EXISTS favorite_recipes (
    recipe_id INTEGER PRIMARY KEY,
    added_at INTEGER NOT NULL,
    FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
);

-- Recent searches (ingredient combinations)
CREATE TABLE IF NOT EXISTS recent_searches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    search_date INTEGER NOT NULL,
    ingredient_names_json TEXT NOT NULL
);
```

#### 2.2 Extend DBInterfaceProtocol
Add methods for new tables:

```swift
protocol DBInterfaceProtocol {
    // Existing methods...

    // Recent ingredients
    func getRecentIngredients(limit: Int) throws -> [Ingredient]
    func recordIngredientUsage(_ ingredient: Ingredient) throws

    // Recent recipes
    func getRecentRecipes(limit: Int) throws -> [Recipe]
    func recordRecipeView(_ recipe: Recipe) throws

    // Favorites
    func getFavoriteRecipes() throws -> [Recipe]
    func addFavorite(_ recipe: Recipe) throws
    func removeFavorite(_ recipe: Recipe) throws
    func isFavorite(_ recipe: Recipe) throws -> Bool

    // Recent searches
    func getRecentSearches(limit: Int) throws -> [[Ingredient]]
    func recordSearch(ingredients: [Ingredient]) throws
}
```

#### 2.3 Create UserDataService
Service to manage user-related data:

```swift
// Model/Services/UserDataService.swift
final class UserDataService {
    private let dbInterface: DBInterfaceProtocol

    // Recent ingredients
    func getRecentIngredients(limit: Int = 10) async throws -> [Ingredient]
    func recordIngredientUsage(_ ingredients: [Ingredient]) async throws

    // Recent recipes
    func getRecentRecipes(limit: Int = 20) async throws -> [Recipe]
    func recordRecipeView(_ recipe: Recipe) async throws

    // Favorites
    func getFavorites() async throws -> [Recipe]
    func toggleFavorite(_ recipe: Recipe) async throws -> Bool
    func isFavorite(_ recipe: Recipe) async throws -> Bool
}
```

---

### Phase 3: UI Completion (Priority: HIGH)

**Goal:** Complete all screens with proper data flow.

#### 3.1 Ingredients Input Screen
- Connect to `UserDataService` for recent ingredients
- Show recent ingredients in `IngredientsInputFastIngredientSelector`
- Record used ingredients when searching

Changes to `IngredientsInputViewModel`:
```swift
@MainActor
final class IngredientsInputViewModel: ObservableObject {
    @Published var recentIngredients: [Ingredient] = []

    private let userDataService: UserDataService

    func loadRecentIngredients() async { ... }
    func onSearchPerformed() async {
        // Record selected ingredients
        try? await userDataService.recordIngredientUsage(Array(selectedIngredients))
    }
}
```

#### 3.2 Recent Recipes Screen (NEW)
Create `RecentRecipesView` and `RecentRecipesViewModel`:

```swift
@MainActor
final class RecentRecipesViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var images: [String: UIImage] = [:]
    @Published var isLoading = false

    private let userDataService: UserDataService
    private let imageService: ImageService

    func loadRecentRecipes() async { ... }
}
```

#### 3.3 Favorites Screen (NEW)
Create `FavoritesView` and `FavoritesViewModel`:

```swift
@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var images: [String: UIImage] = [:]
    @Published var isLoading = false

    private let userDataService: UserDataService
    private let imageService: ImageService

    func loadFavorites() async { ... }
    func removeFavorite(_ recipe: Recipe) async { ... }
}
```

#### 3.4 Recipe Details Screen
Add favorite toggle:

```swift
@MainActor
final class RecipeDetailsViewModel: ObservableObject {
    @Published var recipe: Recipe
    @Published var image: UIImage?
    @Published var isFavorite: Bool = false

    private let userDataService: UserDataService
    private let imageService: ImageService

    func loadData() async { ... }
    func toggleFavorite() async { ... }
}
```

#### 3.5 Update TabContainerView
Replace placeholders with real screens:

```swift
TabView {
    IngredientsInputView(viewModel: ...)
        .tabItem { ... }

    RecentRecipesView(viewModel: ...)
        .tabItem { Label("Recent", systemImage: "clock") }

    FavoritesView(viewModel: ...)
        .tabItem { Label("Favorites", systemImage: "heart") }

    SettingsView(viewModel: ...)
        .tabItem { Label("Settings", systemImage: "gear") }
}
```

---

### Phase 4: Ingredient Suggestions Enhancement (Priority: MEDIUM)

**Goal:** Improve autocompletion and suggestions.

#### 4.1 Smart Suggestions
Combine recent ingredients with search results:

```swift
func getSuggestions(for query: String) async throws -> [Ingredient] {
    if query.isEmpty {
        // Return recent ingredients when no query
        return try await userDataService.getRecentIngredients(limit: 10)
    }

    // Search with FTS and boost recent ingredients
    let searchResults = try await ingredientsService.searchFullIngredients(matching: query)
    let recentNames = Set(recentIngredients.map { $0.name.lowercased() })

    // Sort: recent first, then by relevance
    return searchResults.sorted { a, b in
        let aRecent = recentNames.contains(a.name.lowercased())
        let bRecent = recentNames.contains(b.name.lowercased())
        if aRecent != bRecent { return aRecent }
        return a.name < b.name
    }
}
```

#### 4.2 Popular Ingredients
Track global usage counts and show popular ingredients for new users:

```swift
// Add to DBInterface
func getPopularIngredients(limit: Int) throws -> [Ingredient]
```

---

### Phase 5: Settings Screen (Priority: MEDIUM)

**Goal:** Implement basic settings.

#### 5.1 Settings Structure
```swift
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var currentPlan: SubscriptionPlan = .free
    @Published var recipeCount: Int = 0
    @Published var favoriteCount: Int = 0

    // App info
    let appVersion: String
    let buildNumber: String

    func loadSettings() async { ... }
    func clearRecentData() async { ... }
    func clearFavorites() async { ... }
}

enum SubscriptionPlan {
    case free
    case api      // future
    case ai       // future
}
```

#### 5.2 Settings View Content
- Current subscription plan (free for now)
- Recipe database stats
- Clear recent history
- Clear favorites
- App version/info
- Future: subscription management

---

### Phase 6: Code Quality (Priority: LOW)

**Goal:** Clean up and polish.

#### 6.1 Remove Dead Code
- Delete commented-out SQLite implementation from `DBInterfaceProtocol.swift`
- Remove unused imports
- Clean up print statements (use proper logging)

#### 6.2 Error Handling
- Create unified error types
- Add user-friendly error messages
- Add retry mechanisms where appropriate

#### 6.3 Testing
- Ensure all services have unit tests
- Add UI tests for critical flows
- Test database migrations

---

## Task Checklist

### Phase 1: Foundation Cleanup
- [ ] Create `AppContainer.swift`
- [ ] Inject `AppContainer` via `@EnvironmentObject` in `CookSavvyApp`
- [ ] Move `IngredientsInputViewModel` to separate file
- [ ] Move `RecipesResultViewModel` to separate file
- [ ] Create `TabContainerViewModel`
- [ ] Remove commented code from `DBInterfaceProtocol.swift`
- [ ] Create `DataImportService`
- [ ] Update views to use injected services

### Phase 2: Database Schema Extension
- [ ] Add `recent_ingredients` table
- [ ] Add `recent_recipes` table
- [ ] Add `favorite_recipes` table
- [ ] Add `recent_searches` table
- [ ] Extend `DBInterfaceProtocol` with new methods
- [ ] Implement new methods in `DBInterface`
- [ ] Create `UserDataService`
- [ ] Add unit tests for new DB methods

### Phase 3: UI Completion
- [ ] Update `IngredientsInputViewModel` for recent ingredients
- [ ] Create `RecentRecipesView` and `RecentRecipesViewModel`
- [ ] Create `FavoritesView` and `FavoritesViewModel`
- [ ] Create `RecipeDetailsViewModel`
- [ ] Add favorite toggle to `RecipeDetailsView`
- [ ] Update `TabContainerView` with real screens
- [ ] Record recipe views when user opens details

### Phase 4: Suggestions Enhancement
- [ ] Implement smart suggestions combining recent + search
- [ ] Add popular ingredients query
- [ ] Update `IngredientsInputFastIngredientSelector` to use real data

### Phase 5: Settings
- [ ] Create `SettingsViewModel`
- [ ] Implement `SettingsView` UI
- [ ] Add clear history functionality
- [ ] Add app info display

### Phase 6: Code Quality
- [ ] Remove dead code
- [ ] Replace print statements with logging
- [ ] Review and improve error handling
- [ ] Add missing tests

---

## Notes for Future Phases (Out of Scope Now)

### Monetization (Later)
- StoreKit 2 integration
- Subscription plans: free, api, ai
- Feature gating based on plan
- Limits enforcement

### Camera & AI Detection (Later)
- Camera permission handling
- Photo capture UI
- External LLM API integration
- Ingredient detection from photos

### Online API (Later)
- API client implementation
- Network error handling
- Caching strategy
- Rate limiting

### AI Recipe Generation (Later)
- LLM API integration
- Recipe generation from ingredients
- Quality filtering

---

## Dependencies

Current:
- GRDB (SQLite wrapper)
- Swift CSV (CSV parsing)
- ZIPFoundation (via Unarchiver)

No additional dependencies needed for Phase 1-6.

---

## Getting Started

1. Start with **Phase 1.1** - Create `AppContainer.swift`
2. This unblocks all other changes by providing proper DI
3. Phases can be partially parallelized after Phase 1 is complete
