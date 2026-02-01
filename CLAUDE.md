# CookSavvy

A hobby iOS recipe app that suggests recipes based on user-provided ingredients.

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI (UIKit only when absolutely necessary)
- **Philosophy:** Maximize use of Apple frameworks

## Subscription Tiers

| Tier | Recipe Source | Ingredient Detection |
|------|---------------|---------------------|
| Free | Local database | Manual text input only |
| API | REST API (curated recipes) | AI photo recognition |
| AI | AI-generated recipes | AI photo recognition |

## App Screens

| Screen | Description |
|--------|-------------|
| **Ingredients Input** (initial) | Text input with autocomplete, camera input (AI recognition on paid tiers), recent ingredients |
| **Search Results** | Recipe table with name, image, complexity, cook time |
| **Recipe Details** | Full recipe information |
| **Recent Recipes** | Recently viewed recipes (same layout as search results) |
| **Favorites** | Bookmarked recipes (same layout as search results) |
| **Settings** | Subscription plan, usage limits, preferences |

> All screens are subject to extension and modification.

## Architecture Rules

### MVVM + Coordinator Pattern
- **Views** contain **only** a `viewModel` property
- All state/variables live inside the **ViewModel**
- **Coordinators** handle navigation and ViewModel creation
- Strict separation of concerns:
  - Views: UI presentation only
  - ViewModels: Business logic and state
  - Coordinators: Navigation flow
  - Services: Data operations

### Coordinator Hierarchy
- `AppCoordinator`: Root coordinator managing tab-level coordinators
- Feature coordinators: `IngredientsCoordinator`, `FavoritesCoordinator`, `RecentRecipesCoordinator`, `SettingsCoordinator`
- Each coordinator owns its navigation stack and sheet presentations
- ViewModels hold weak references to coordinators for navigation

### Dependency Injection
- `AppContainer`: Singleton holding all shared service instances
- Services initialized once and injected into ViewModels via coordinators
- Maintains single source of truth for app-wide dependencies

### Service Layer
- **Data Services**: `RecipeService`, `IngredientsService`, `UserDataService`
- **Infrastructure**: `ImageService`, `DatabaseInitializationService`, `DataImportService`
- **Feature Services**: `IngredientDetectionService`, `SubscriptionService`
- **Network Layer**: `NetworkService`, `URLBuilder`, `NetworkRequest`, `NetworkResponse`, `NetworkError`
- All services conform to protocols for testability

### Code Organization
- Create services as needed
- Follow **Single Responsibility Principle**
- Maintain consistent app structure and best practices

### Code Duplication Policy
- **No duplication** — search for existing solutions first
- Refactor only when necessary; prefer adding new methods over modifying existing ones
- Duplication allowed only for:
  - Unrelated modules
  - Logic that may diverge in the future
  - **Requires explicit approval**

## Workflow Rules

- **Ask before coding** if you need more info (unless instructed otherwise)
- **Comments:** Default is `none`. Levels: `none` | `needed only` | `every line` — wait for instruction
