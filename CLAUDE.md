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

### MVVM Pattern
- Views contain **only** a `viewModel` property
- All state/variables live inside the ViewModel
- Strict separation of concerns

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
