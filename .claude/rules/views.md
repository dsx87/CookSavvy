---
paths:
  - "CookSavvy/Views/**"
---

# App Screens

| Screen | Description |
|--------|-------------|
| **Discover** (tab 1) | Two-state flow: ingredient selection (grid, categories, search, recent/saved cards, free pantry staples) and recipe results (mood filter, hero best match, recipe rows) |
| **My Kitchen** (tab 2) | Saved recipes, recent cooks, shopping list shortcut, compact stats, user recipes + create card, achievements, settings (gear icon in nav bar) |
| **Recipe Details** | Hero image, floating back/bookmark actions, stats row, ingredients (with "Add Missing to List" button for premium), steps, sticky Start Cooking CTA |
| **Recipe List** | Reusable See All destination for recent, saved, and user recipes |
| **Cook Mode** | Full-screen step-by-step cooking flow with progress ring, timer, and prev/next navigation |
| **Create Recipe** | 5-step wizard: Name & Photo → Ingredients → Steps → Details → Review & Save |
| **Settings** | Subscription plan, usage limits, account (Sign in with Apple / Sign Out), preferences (accessed from My Kitchen nav bar) |
| **Camera** | Camera capture for AI ingredient detection (free users: 5/week via `CameraScanTracker`) |
| **Upgrade** | CookSavvy+ paywall with monthly trial messaging and annual best-value option |
| **Onboarding** | Camera-first first-launch walkthrough: 2 static intro pages followed by an embedded camera scan page; skip/type fallback lands on Discover ingredient selection and a successful first scan hands ingredients to Discover for immediate results |
| **Shopping List** | Premium checklist of missing ingredients grouped by recipe; swipe-to-delete, toggle checked, clear done; sheet from Recipe Details or My Kitchen |
| **Tab Container** | Root tab bar with 2 tabs: Discover + My Kitchen |

> All screens are subject to extension and modification.

## File Map

```
Views/
├── Shared/
│   ├── AsyncImageDisk.swift
│   ├── TabContainerView.swift
│   ├── RecipeCardComponents.swift   — RecipeImage, MiniRecipeCard, RecipeRow (shared across screens)
│   └── CommonComponents.swift       — StarRating, StatPill (shared across screens)
├── Discover/                        — Two-state discover screen (DiscoverView + DiscoverViewModel + DiscoverComponents)
├── Journey/                         — Journey screen (JourneyView + JourneyViewModel + JourneyComponents)
├── RecipeList/                      — Recipe list (RecipeListView + RecipeListViewModel)
├── RecipeDetails/                   — Recipe details with hero image + sticky CTA
├── CookMode/                        — Cook mode with step nav + timer (CookModeView + CookModeViewModel)
├── CreateRecipe/                    — Create recipe wizard (CreateRecipeView + CreateRecipeViewModel)
├── Camera/                          — Camera capture screen
├── ShoppingList/                    — Shopping list (ShoppingListView + ShoppingListViewModel)
├── Settings/                        — Settings screen
├── Upgrade/                         — Subscription upgrade screen (single CookSavvy+ plan)
└── Onboarding/                      — First-launch walkthrough with embedded camera page (OnboardingView + OnboardingViewModel + OnboardingCameraPage)
```
