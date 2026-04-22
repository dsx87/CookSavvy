# CookSavvy — High-Level Design (HLD)

> Generated from source code analysis.

---

## Table of Contents

1. [App Overview](#1-app-overview)
2. [System Architecture Layers](#2-system-architecture-layers)
3. [Coordinator Hierarchy](#3-coordinator-hierarchy)
4. [AppContainer / Dependency Injection](#4-appcontainer--dependency-injection)
5. [Screen Inventory & Navigation Map](#5-screen-inventory--navigation-map)
6. [Data Models](#6-data-models)
7. [Database Schema](#7-database-schema)
8. [Service Layer Architecture](#8-service-layer-architecture)
9. [Recipe Discovery Data Flow](#9-recipe-discovery-data-flow)
10. [Recipe Source Strategy](#10-recipe-source-strategy)
11. [AI / LLM Provider Layer](#11-ai--llm-provider-layer)
12. [Authentication System](#12-authentication-system)
13. [Subscription & Feature Gating](#13-subscription--feature-gating)
14. [Onboarding Flow](#14-onboarding-flow)
15. [Cook Mode State Machine](#15-cook-mode-state-machine)
16. [Create Recipe Wizard](#16-create-recipe-wizard)
17. [Theme System](#17-theme-system)
18. [Build Configuration Matrix](#18-build-configuration-matrix)
19. [ViewModel State Summary](#19-viewmodel-state-summary)
---

## 1. App Overview

CookSavvy is a hobby iOS recipe app. Users select or scan ingredients, receive recipe suggestions, cook step-by-step, save favourites, track cooking history, and earn achievements.

### Subscription Tiers

| Tier | Display Name | Product ID | Recipe Sources | Ingredient Detection | Camera |
|------|-------------|------------|----------------|----------------------|--------|
| Free | Free | — | `OfflineRecipeSource` (local SQLite only) | Manual text input | 5 scans/week (`CameraScanTracker`, UserDefaults, resets when `Calendar.current` enters a new week/year) |
| Premium | CookSavvy+ | `com.cooksavvy.subscription.premium` | `OfflineRecipeSource` + `OnlineRecipeSource` (Spoonacular/Supabase) + `AIRecipeSource` | Unlimited AI photo recognition | Unlimited |

### Gated Features (`PaidFeature` enum)

| Case | Description |
|------|-------------|
| `cameraIngredientDetection` | AI-powered photo ingredient detection |
| `onlineRecipes` | Recipes from online API providers |
| `aiRecipes` | AI-generated recipes |
| `shoppingList` | Shopping list with missing ingredients |

---

## 2. System Architecture Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER (SwiftUI)                            │
│  DiscoverView · JourneyView · RecipeDetailsView · CookModeView · Others   │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    NAVIGATION LAYER (Coordinators)                         │
│  AppCoordinator ──▶ DiscoverCoordinator                                   │
│                 ──▶ JourneyCoordinator ──▶ SettingsCoordinator            │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│              DEPENDENCY INJECTION (AppContainer @MainActor singleton)      │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SERVICE LAYER (Protocol-backed)                         │
│  Recipe · Ingredient · Auth · Subscription · AI · Network · Infrastructure│
└────────────────────┬────────────────────────────────┬───────────────────────┘
                     ▼                                ▼
┌────────────────────────────────────┐  ┌─────────────────────────────────────┐
│          DATA LAYER                │  │        EXTERNAL SYSTEMS             │
│  GRDB/SQLite (9 tables + FTS5)    │  │  Supabase Edge Functions            │
│  UserDefaults (CameraScanTracker) │  │  Supabase Auth (Anon + SIWA)        │
│  Disk Cache (ImageService)        │  │  Spoonacular API (legacy)           │
│  Keychain/plist (APIKeys.plist)   │  │  OpenAI/Gemini (legacy direct)      │
│                                    │  │  StoreKit 2 (App Store)             │
└────────────────────────────────────┘  └─────────────────────────────────────┘
```

**Layer responsibilities:**

| Layer | Technology | Responsibility |
|-------|-----------|----------------|
| Presentation | SwiftUI views, `@ObservedObject` ViewModels | UI rendering only; zero business logic |
| Navigation | Coordinator classes owning `NavigationPath`, sheets, fullScreenCovers | Screen transitions, ViewModel construction |
| DI | `AppContainer` (`@MainActor` singleton) | Single creation and ownership of all services |
| Services | Swift classes/structs conforming to protocols | Business logic, data orchestration |
| Data | GRDB (SQLite), UserDefaults, disk cache | Persistence; all dates as Unix timestamps |
| External | Supabase, StoreKit 2, ASAuthorizationController | AI/API calls, purchases, Apple auth |

---

## 3. Coordinator Hierarchy

```
CookSavvyApp (entry point)
├── [first launch] ──▶ OnboardingView (sheet/modal)
└── [returning user] ──▶ AppCoordinator (root)
                          ├── DiscoverCoordinator (Tab 0 — NavigationStack)
                          │   ├── [root]           DiscoverView (two-state: selection + results)
                          │   ├── [push]           RecipeDetailsView
                          │   ├── [push]           RecipeListView
                          │   ├── [fullScreenCover] CookModeView
                          │   ├── [sheet]          CameraView
                          │   ├── [sheet]          CreateRecipeView
                          │   ├── [sheet]          ShoppingListView
                          │   └── [sheet]          UpgradeView
                          │
                          └── JourneyCoordinator (Tab 1 — NavigationStack)
                              ├── [root]           JourneyView
                              ├── [push]           RecipeDetailsView
                              ├── [push]           RecipeListView
                              ├── [fullScreenCover] CookModeView
                              ├── [sheet]          ShoppingListView
                              ├── [sheet]          CreateRecipeView
                              ├── [sheet]          UpgradeView
                              └── [sheet]          SettingsCoordinator
                                                    ├── [root]  SettingsView
                                                    └── [sheet] UpgradeView
```

**Navigation type key:**

| Type | SwiftUI mechanism | Used for |
|------|------------------|---------|
| push | `NavigationStack` path append | Drill-down screens |
| sheet | `.sheet(isPresented:)` | Modal flows that can be dismissed |
| fullScreenCover | `.fullScreenCover(isPresented:)` | Immersive full-screen flows (CookMode) |

---

## 4. AppContainer / Dependency Injection

`AppContainer` is a `@MainActor` singleton that creates and owns every service. Coordinators and ViewModels receive protocol-typed references — never the concrete type.

```
                              ┌────────────────┐
                              │  AppContainer   │
                              │  (@MainActor    │
                              │   singleton)    │
                              └───────┬────────┘
          ┌───────────┬───────────┬───┴────┬──────────────┐
          ▼           ▼           ▼        ▼              ▼
┌─────────────┐ ┌──────────┐ ┌─────────┐ ┌───────────┐ ┌──────────────┐
│Recipe Domain│ │Ingredient│ │User Data│ │Auth & Sub │ │Infrastructure│
│             │ │  & AI    │ │         │ │           │ │              │
│ RecipeServ  │ │ IngServ  │ │ UserData│ │ AuthServ  │ │ NetworkServ  │
│ RecommServ  │ │ Detection│ │ Shopping│ │ AppleSIMgr│ │ DBInterface  │
│ CuratedColl │ │ CamScan  │ │ Dietary │ │ SupabaseCl│ │ DBInitServ   │
│             │ │ AIService│ │ Analytic│ │ SubscripSv│ │ DataImport   │
│             │ │          │ │         │ │           │ │ ImageServ    │
│             │ │          │ │         │ │           │ │ LoggingServ  │
└─────────────┘ └──────────┘ └─────────┘ └───────────┘ └──────────────┘
```

---

## 5. Screen Inventory & Navigation Map

```
                            ┌──────────────┐
                            │  App Launch   │
                            └──────┬───────┘
                                   ▼
                          ┌─────────────────┐
                          │   Onboarding    │  No
                          │   complete?     ├──────────▶ OnboardingView (3 pages)
                          └───────┬─────────┘            │ skip/type/scan
                            Yes   │    ┌─────────────────┘
                                  ▼    ▼
                          ┌──────────────────┐
                          │ TabContainerView │
                          │    (2 tabs)      │
                          └──┬───────────┬───┘
                             ▼           ▼
                  ┌──────────────┐  ┌──────────────┐
                  │DiscoverView  │  │ JourneyView  │
                  │   (Tab 0)    │  │   (Tab 1)    │
                  └──┬───────────┘  └──┬───────────┘
                     │                 │
  ┌──────────────────┤                 ├──────────────────┐
  ▼                  ▼                 ▼                  ▼
Ingredient       Recipe            Saved/Recent/       Create
Selection ◄──▶ Results             User Recipes         Recipe
  │              │                    │                   │
  │    ┌─────────┤                    ▼                   │
  ▼    ▼         ▼             RecipeListView             │
Camera RecipeDetails ──▶ CookMode (fullscreen)            │
  │         │                                             │
  │         ▼                                             │
  │    ShoppingList (premium)     Settings ◄── gear icon  │
  │                                  │                    │
  └──────────▶ UpgradeView ◄────────┘◄───────────────────┘
```

---

## 6. Data Models

```
┌──────────────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│        Recipe            │     │   RecipeStep      │     │  AdditionalInfo  │
├──────────────────────────┤     ├──────────────────┤     ├──────────────────┤
│ id: String (= title)     │────▶│ text: String      │     │ time: String     │
│    image: String         │  *  │ timerMinutes: Int  │     │ servings: Int    │
│    tagline: String       │     └──────────────────┘     │ complexity: Str  │
│    author: String        │──────────────────────────────▶│ calories: Int    │
│    emoji: String         │  1                            └──────────────────┘
│    cuisine: String       │
│    userRating: Double    │     ┌──────────────────────┐
│    apiRating: Double     │────▶│     Ingredient       │
│    matchPercentage: Dbl  │  *  ├──────────────────────┤
│    matchReason: String   │     │ PK name: String      │
│    isUserCreated: Bool   │     │    description: Str   │
│    source: SourceType    │     │    pictureFileName    │
│    cookTimeMinutes: Int  │     │    foodGroup: Str     │
│    shareText: String     │     │    foodSubgroup: Str  │
└──────────┬───────────────┘     │    emoji: String      │
           │                     │    category: Category  │
           │                     └──────────────────────┘
           │
           ▼ *
┌──────────────────────┐    ┌──────────────────────┐    ┌──────────────────┐
│   CookingSession     │    │    ShoppingItem       │    │   Achievement    │
├──────────────────────┤    ├──────────────────────┤    ├──────────────────┤
│ PK id: Int           │    │ PK id: Int           │    │ PK id: String    │
│    recipeId: Int      │    │    name: String       │    │    title: String │
│    recipeTitle: Str   │    │    isChecked: Bool    │    │    description   │
│    cookedAt: Date     │    │    addedAt: Date      │    │    emoji: String │
│    durationSecs: TI   │    │    recipeTitle: Str   │    │    colorHex: Str │
│    rating: Int        │    └──────────────────────┘    │    category      │
│    durationFormatted  │                                │    maxProgress   │
│    rescuedIngredients │    ┌──────────────────────┐    │    isUnlocked    │
└──────────────────────┘    │  SubscriptionPlan    │    │    unlockedAt    │
                            ├──────────────────────┤    └──────────────────┘
                            │ PK rawValue: String  │
                            │    tier: Int          │
                            └──────────────────────┘
```

**Achievement IDs (10 total):**

| ID | Emoji | Title | MaxProgress | Category |
|----|-------|-------|-------------|----------|
| `first_cook` | 👨‍🍳 | First Cook | 1 | .general |
| `week_streak` | 🔥 | Week Streak | 7 | .general |
| `recipe_creator` | 📝 | Recipe Creator | 1 | .general |
| `ten_recipes` | ⭐ | Ten Recipes | 10 | .general |
| `five_created` | 📚 | Five Created | 5 | .general |
| `fifty_recipes` | 👑 | Fifty Recipes | 50 | .general |
| `hour_cooking` | ⏰ | Hour Cooking | 10 | .general |
| `fridge_cleaner` | ♻️ | Fridge Cleaner | 5 | .antiWaste |
| `ingredient_master` | 🧑‍🍳 | Ingredient Master | 50 | .antiWaste |
| `scan_pro` | 📸 | Scan Pro | 20 | .antiWaste |

---

## 7. Database Schema

```
┌──────────────────────┐         ┌────────────────────────────────────┐
│   ingredients        │         │            recipes                 │
├──────────────────────┤         ├────────────────────────────────────┤
│ PK name TEXT         │         │ PK id INTEGER                     │
│    description TEXT   │         │    title TEXT                      │
│    picture_file_name │         │    image TEXT                      │
│    food_group TEXT    │         │    instructions_json TEXT          │
│    food_subgroup TEXT│         │    ingredients_json TEXT           │
└──────────┬───────────┘         │    cleaned_ingredients_json TEXT   │
           │                     │    additional_info_json TEXT       │
     ┌─────┘                     │    source TEXT                     │
     │  ┌────────────────┐       │    tagline TEXT                    │
     │  │ingredients_fts │       │    user_rating REAL                │
     │  │(FTS5 external) │       │    api_rating REAL                 │
     │  │ name TEXT       │       │    author TEXT                     │
     │  └────────────────┘       │    is_user_created INTEGER         │
     │                           │    emoji TEXT · cuisine TEXT        │
     │                           └─────────────┬──────────────────────┘
     │                                         │
     │    ┌────────────────────────┐            │    ┌────────────────┐
     │    │  recipe_ingredients    │            │    │  recipes_fts   │
     └───▶│ FK recipe_id INTEGER  │◄───────────┘    │ (FTS5 external)│
          │ FK ingredient_name    │                  │  title TEXT    │
          └────────────────────────┘                  └────────────────┘

┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
│  recent_ingredients  │  │   recent_recipes     │  │  favorite_recipes    │
├──────────────────────┤  ├──────────────────────┤  ├──────────────────────┤
│ PK ingredient_name   │  │ PK recipe_id INTEGER │  │ PK recipe_id INTEGER│
│    last_used_at INT  │  │    last_viewed_at INT│  │    added_at INTEGER  │
│    use_count INTEGER │  │    view_count INTEGER│  └──────────────────────┘
└──────────────────────┘  └──────────────────────┘

┌──────────────────────┐  ┌──────────────────────────────┐  ┌─────────────────────┐
│   recent_searches    │  │      cooking_sessions        │  │   shopping_items    │
├──────────────────────┤  ├──────────────────────────────┤  ├─────────────────────┤
│ PK id INTEGER        │  │ PK id INTEGER                │  │ PK id INTEGER       │
│    search_date INT   │  │ FK recipe_id INTEGER         │  │    name TEXT         │
│    ingredient_names  │  │    cooked_at INTEGER         │  │    is_checked INT   │
│    _json TEXT        │  │    duration_seconds INTEGER   │  │    added_at INTEGER │
└──────────────────────┘  │    rating INTEGER             │  │    recipe_title TEXT│
                          │    ingredients_rescued_json   │  └─────────────────────┘
                          └──────────────────────────────┘
```

**Index summary:**

| Table | Index | Columns | Notes |
|-------|-------|---------|-------|
| `ingredients` | FTS5 triggers (ai/ad/au) | `name` | Full-text search |
| `recipes` | `idx_recipes_title` | `title` | FTS5 external content |
| `recipe_ingredients` | `idx_recipe_ingredients_name` | `ingredient_name` | — |
| `recipe_ingredients` | `idx_recipe_ingredients_composite` | `recipe_id, ingredient_name` | — |
| `recent_ingredients` | `idx_recent_ingredients_last_used` | `last_used_at DESC` | — |
| `recent_recipes` | `idx_recent_recipes_last_viewed` | `last_viewed_at DESC` | — |
| `favorite_recipes` | `idx_favorite_recipes_added` | `added_at DESC` | — |
| `recent_searches` | `idx_recent_searches_date` | `search_date` | Auto-trimmed to last 50 |
| `cooking_sessions` | `idx_cooking_sessions_date` | `cooked_at DESC` | — |
| `shopping_items` | `idx_shopping_items_added` | `added_at DESC` | — |

> All date/time columns store Unix timestamps as `INTEGER`. In-memory recipe cache: max 100 items. While the app has no production users, prefer destructive development schema resets over accumulating migrations for schema redesigns.

---

## 8. Service Layer Architecture

```
RECIPE DOMAIN                          INGREDIENT DOMAIN
─────────────                          ─────────────────
RecipeServiceProtocol                  IngredientsServiceProtocol
  └──▶ RecipeService                     └──▶ IngredientsService

RecipeSourceProtocol                   IngredientDetectionServiceProtocol
  ├──▶ OfflineRecipeSource               └──▶ AIIngredientDetectionAdapter
  ├──▶ OnlineRecipeSource
  └──▶ AIRecipeSource                  CameraScanTrackerProtocol
                                         └──▶ CameraScanTracker (UserDefaults)
RecipeAPIProviderProtocol
  ├──▶ SpoonacularProvider (legacy)
  └──▶ SupabaseRecipeAPIProvider       USER DATA DOMAIN
                                       ────────────────
RecipeRecommendationServiceProtocol    UserDataServiceProtocol
  └──▶ RecipeRecommendationService       └──▶ UserDataService

CuratedCollectionServiceProtocol       ShoppingListServiceProtocol
  └──▶ CuratedCollectionService          └──▶ ShoppingListService

                                       DietaryPreferencesProtocol
                                         └──▶ DietaryPreferences (UserDefaults)

AUTH DOMAIN                            SUBSCRIPTION DOMAIN
───────────                            ───────────────────
AuthServiceProtocol                    SubscriptionServiceProtocol
  ├──▶ SupabaseAuthService (keys)        ├──▶ StoreKitSubscriptionService (RELEASE)
  ├──▶ MockAuthService (DEBUG no-keys/UITest)
  │                                      └──▶ MockSubscriptionService (DEBUG)
  └──▶ NoOpAuthService (RELEASE/no-keys)

SupabaseClientProviderProtocol         AI DOMAIN
  └──▶ SupabaseClientProvider          ─────────
                                       AIServiceProtocol
AppleSignInManager                       └──▶ AIService
  (ASAuthorizationController + nonce)
                                       LLMProviderProtocol
NETWORK DOMAIN                           ├──▶ MockLLMProvider (UITest)
──────────────                           ├──▶ SupabaseLLMProvider (if keys)
NetworkServiceProtocol                   ├──▶ OpenAIProvider (legacy)
  └──▶ NetworkService                    └──▶ GeminiProvider (legacy)

                                       SupabaseServiceAssembly
INFRASTRUCTURE                           ├──▶ SupabaseLLMProvider
──────────────                           └──▶ SupabaseRecipeAPIProvider
DBInterfaceProtocol ──▶ DBInterface (GRDB SQLite)
DatabaseInitializationServiceProtocol ──▶ DatabaseInitializationService
DataImportServiceProtocol ──▶ DataImportService ──▶ CSVParser
ImageServiceProtocol ──▶ ImageService (disk cache)
LoggingServiceProtocol ──▶ LoggingService (os.Logger)
AnalyticsServiceProtocol ──▶ AnalyticsService

Key dependency links:
  AIService ──uses──▶ LLMProviderProtocol
  AIIngredientDetectionAdapter ──uses──▶ AIServiceProtocol
  OnlineRecipeSource ──uses──▶ RecipeAPIProviderProtocol
  AIRecipeSource ──uses──▶ AIServiceProtocol
  RecipeService ──uses──▶ OfflineRecipeSource + OnlineRecipeSource + AIRecipeSource
  Recipe/Ingredient/UserData domains ──use──▶ DBInterfaceProtocol
```

---

## 9. Recipe Discovery Data Flow

```
User      DiscoverView    DiscoverVM     RecipeService    Offline   Online    AI     MoodRanker  RecommServ
 │             │              │               │             │         │       │          │           │
 │──tap Find──▶│              │               │             │         │       │          │           │
 │             │──findRecipes▶│               │             │         │       │          │           │
 │             │              │──fetchRecipes─▶             │         │       │          │           │
 │             │              │               │──fetch──────▶│        │       │          │           │
 │             │              │               │─────fetch────────────▶│       │          │           │
 │             │              │               │──────fetch───────────────────▶│          │           │
 │             │              │               │◀─SQLite─────│         │       │          │           │
 │             │              │               │◀────Supabase API─────│       │          │           │
 │             │              │               │◀─────LLM recipes────────────│          │           │
 │             │              │               │                                         │           │
 │             │              │               │──merge + deduplicate──┐                 │           │
 │             │              │               │◀─────────────────────┘                 │           │
 │             │              │               │──rank(recipes, mood)────────────────────▶│           │
 │             │              │               │◀──────sorted by mood + match%───────────│           │
 │             │              │               │──boost(recipes, history)────────────────────────────▶│
 │             │              │               │◀──────boosted by personalization────────────────────│
 │             │              │◀──final list──│             │         │       │          │           │
 │             │◀─Published──│               │             │         │       │          │           │
 │◀─hero+rows─│              │               │             │         │       │          │           │
```

---

## 10. Recipe Source Strategy

```
                     ┌──────────────────────────┐
                     │ fetchRecipes(ingredients) │
                     └────────────┬─────────────┘
                                  ▼
                     ┌──────────────────────────┐
                     │   subscriptionPlan?      │
                     └──────┬───────────┬───────┘
                     .free  │           │  .premium
                            ▼           ▼
              ┌──────────────┐   ┌───────────────────────────────────┐
              │ Offline only │   │        All 3 Sources              │
              └──────┬───────┘   └───┬──────────┬──────────┬────────┘
                     │               ▼          ▼          ▼
                     │         ┌──────────┐ ┌────────┐ ┌────────┐
                     │         │ Offline  │ │ Online │ │   AI   │
                     │         │ SQLite   │ │ API    │ │  LLM   │
                     │         │ FTS5     │ │Provider│ │Provider│
                     │         └────┬─────┘ └───┬────┘ └───┬────┘
                     │              │     ┌─────┘     ┌────┘
                     │              │     ▼           ▼
                     │              │  ┌──────────┐ ┌──────────────┐
                     │              │  │ Supabase │ │ Mock (UITest)│
                     │              │  │ edge fn  │ │ or Supabase  │
                     │              │  │(if keys) │ │   (if keys)  │
                     │              │  └────┬─────┘ └──────┬───────┘
                     ▼              ▼       ▼              ▼
                  ┌───────────────────────────────────────────────┐
                  │          Merge + Deduplicate by title         │
                  └──────────────────────┬───────────────────────┘
                                         ▼
                  ┌───────────────────────────────────────────────┐
                  │   RecipeMoodRanker (score by mood + match%)   │
                  └──────────────────────┬───────────────────────┘
                                         ▼
                  ┌───────────────────────────────────────────────┐
                  │  RecipeRecommendationService (boost history)  │
                  └──────────────────────┬───────────────────────┘
                                         ▼
                  ┌───────────────────────────────────────────────┐
                  │           Return ranked Recipe list           │
                  └───────────────────────────────────────────────┘
```

---

## 11. AI / LLM Provider Layer

```
                     ┌───────────────────────┐
                     │ Runtime Configuration │
                     └───┬──────┬────────┬───┘
                         │      │        │
          UI Testing ────┘      │        └──── No Supabase keys
                                │
                         Supabase configured
                                │
          ┌─────────────────────┼────────────────────────┐
          ▼                     ▼                        ▼
┌──────────────────┐  ┌─────────────────────┐  ┌──────────────────┐
│ MockLLMProvider  │  │SupabaseServiceAssembly│ │ No LLM provider │
│ (deterministic)  │  └────┬────────┬────────┘ │ (unavailable)    │
└────────┬─────────┘       │        │          └────────┬─────────┘
         │                 ▼        ▼                   │
         │  ┌─────────────────┐  ┌──────────────────┐   │
         │  │SupabaseLLMProv  │  │SupabaseRecipeAPI │   │
         │  │(LLMProviderProt)│  │   Provider       │   │
         │  └────────┬────────┘  └────────┬─────────┘   │
         │           │                    │             │
         │      ┌────▼─────────┐    ┌─────▼──────────┐  │
         │      │Supabase Edge │    │Supabase Edge   │  │
         │      │Fn: LLM/detect│    │Fn: recipe srch │  │
         │      └──────────────┘    └────────────────┘  │
         │                                              │
         └──────────────┬───────────────────────────────┘
                        ▼
               ┌─────────────────┐
               │    AIService    │
               │(AIServiceProto) │
               └───┬─────────┬───┘
                   │         │
      detectIngredients   generateRecipes
                   │         │
                   ▼         ▼
    ┌──────────────────┐  ┌──────────────────┐
    │AIIngredientDetect│  │  AIRecipeSource  │
    │   Adapter        │  │(RecipeSourceProt)│
    └──────────────────┘  └──────────────────┘

    Legacy (not used in active RELEASE path):
    ┌────────────────┐ ┌────────────────┐ ┌──────────────────┐
    │ OpenAIProvider │ │ GeminiProvider │ │SpoonacularProvider│
    └────────────────┘ └────────────────┘ └──────────────────┘

    API Keys: APIKeys.plist (SUPABASE_URL, SUPABASE_ANON_KEY) — gitignored
```

---

## 12. Authentication System

```
  App Start
      │
      ▼
  Runtime configuration
      ├── UI testing or DEBUG without Supabase keys ──▶ MockAuthService
      ├── RELEASE without Supabase keys ──────────────▶ NoOpAuthService
      └── Supabase keys configured ───────────────────▶ SupabaseAuthService
                                                          │
                                                          ▼
                                                Existing session?
                                                    │        │
                                                  Yes        No
                                                    │        ▼
                                                    │  signInAnonymously
                                                    │        │
                                                    ▼        ▼
                                                Anonymous User
                                                (supabase UUID)
                                                    │
                         ┌──────────────────────────┴──────────────────────────┐
                         ▼                                                     ▼
              Sign in with Apple                                           Sign Out
              (AppleSignInManager)                                      (clear session)
                         │                                                     │
                         ▼                                                     ▼
              SHA256 nonce + ASAuthorizationController                 signInAnonymously
                         │
                         ▼
              Apple ID credential -> identityToken
                         │
                         ▼
              SupabaseAuthService.linkIdentity
              (anonymous -> Apple account)
                         │
                         ▼
              Named User (persistent Apple)

  AuthState (SettingsViewModel):
    .unauthenticated │ .anonymous │ .authenticated (Apple ID)
```

---

## 13. Subscription & Feature Gating

```
                    ┌───────────────────────┐
                    │ Feature access request│
                    └──────────┬────────────┘
                               ▼
              ┌────────────────────────────────────┐
              │         PaidFeature check          │
              └──┬──────┬──────────┬──────────┬────┘
                 │      │          │          │
    cameraDetection  onlineRecipes  aiRecipes  shoppingList
                 │      │          │          │
                 ▼      ▼          ▼          ▼
  ┌───────────────┐  ┌────────┐ ┌────────┐ ┌────────┐
  │premium or     │  │premium?│ │premium?│ │premium?│
  │scans remain?  │  └──┬──┬──┘ └──┬──┬──┘ └──┬──┬──┘
  └──┬──┬──┬──────┘  yes│  │no  yes│  │no  yes│  │no
  prem│  │free│         ▼  ▼      ▼  ▼      ▼  ▼
     │  │  + <5     Online  Skip  AI   Skip  Show  Show
     │  │     │     Source  online Src  AI    List  Upgrade
     ▼  ▼     ▼     active        active
  Unlim Allow  Show
  ited  scan  Upgrade ──────────────────────────────┐
       (+inc)  View                                  │
                                                     ▼
                                           ┌──────────────────┐
                                           │   UpgradeView    │
                                           │   CookSavvy+     │
                                           └────┬────────┬────┘
                                            buy │        │ restore
                                                ▼        ▼
                                           StoreKit 2 purchase/restore
                                                │        │
                                                └───┬────┘
                                                    ▼
                                           SubscriptionService
                                           updates currentPlan
                                                    │
                                                    ▼
                                           .premium unlocked

  CameraScanTracker (UserDefaults):
    week/year = Calendar.current │ resets on locale calendar week boundary │ max 5/week free
```

---

## 14. Onboarding Flow

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                     ONBOARDING FLOW                             │
  │                                                                 │
  │  [First Launch: onboardingComplete=false]                       │
  │       │                                                         │
  │       ▼                                                         │
  │  ┌──────────┐   swipe    ┌──────────┐   swipe    ┌───────────┐ │
  │  │  Page 0  │──────────▶│  Page 1  │──────────▶│  Page 2   │ │
  │  │  static  │           │  static  │           │  Camera   │ │
  │  │  intro   │           │  feature │           │  Scan     │ │
  │  │ (hero art│           │highlights│           │  Page     │ │
  │  └──────────┘           └──────────┘           └─────┬─────┘ │
  │                                                      │       │
  │                        ┌─────────────────────────────┐│       │
  │                        │                             ││       │
  │                        ▼                             ▼│       │
  │                ┌──────────────┐              ┌────────┴───┐   │
  │                │ Start Scan   │              │ Skip/Type  │   │
  │                └──────┬───────┘              │ fallback   │   │
  │                       ▼                      └──────┬─────┘   │
  │              ┌─────────────────┐                    │         │
  │              │ Camera active   │                    │         │
  │              └───────┬─────────┘                    │         │
  │                      ▼                              │         │
  │              ┌─────────────────┐                    │         │
  │              │   Processing    │                    │         │
  │              └──┬──────┬───┬──┘                    │         │
  │          found  │  empty│   │error                  │         │
  │                 ▼      ▼   ▼                        │         │
  │          ┌────────┐ try  retry                      │         │
  │          │Detected│ again again                     │         │
  │          └───┬────┘                                 │         │
  │              │                                      │         │
  │              ▼                                      ▼         │
  │  ┌─────────────────────────────────────────────────────────┐  │
  │  │  DiscoverView (with detected ingredients or empty)      │  │
  └──┴─────────────────────────────────────────────────────────┴──┘
```

---

## 15. Cook Mode State Machine

```
  ┌─────────────────────────────────────────────────────────────┐
  │                   COOK MODE STATE MACHINE                    │
  │                                                              │
  │  CookModeView appears (currentStep = 0)                      │
  │       │                                                      │
  │       ▼                                                      │
  │  ┌─────────────────────────────┐                             │
  │  │      Displaying Step        │◄─────────────────────────┐  │
  │  │  currentStep: Int           │                          │  │
  │  │  step text + optional timer │                          │  │
  │  └──┬──────┬──────────┬────────┘                          │  │
  │     │      │          │                                   │  │
  │     │   ◄Prev      Next►                                  │  │
  │     │  (step-1)   (step+1, mark completed)                │  │
  │     │                                                     │  │
  │     │  [has timer]                                        │  │
  │     ▼                                                     │  │
  │  ┌──────────────────┐     pause     ┌──────────────┐      │  │
  │  │  Timer Running   │◄────────────▶│ Timer Paused │      │  │
  │  │  seconds counting│    resume    └──────────────┘      │  │
  │  └────────┬─────────┘                                     │  │
  │           │ timer reaches 0                               │  │
  │           └───────────────────────────────────────────────┘  │
  │                                                              │
  │  [currentStep == last step]                                  │
  │       │                                                      │
  │       ▼                                                      │
  │  ┌──────────────────┐                                        │
  │  │   Final Step     │                                        │
  │  │ Next → "Finish"  │                                        │
  │  └────────┬─────────┘                                        │
  │           ▼                                                  │
  │  ┌──────────────────────────┐                                │
  │  │     Feedback Sheet       │                                │
  │  │  feedbackRating: 1-5     │                                │
  │  └──┬──────────────────┬────┘                                │
  │     │ submit           │ dismiss                              │
  │     ▼                  ▼                                     │
  │  ┌──────────────────────────┐                                │
  │  │  Save CookingSession    │                                 │
  │  │  (recipeId, duration,   │                                 │
  │  │   rating, rescued ingr) │                                 │
  │  └────────────┬────────────┘                                 │
  │               ▼                                              │
  │       Dismiss fullScreenCover                                │
  └──────────────────────────────────────────────────────────────┘
```

---

## 16. Create Recipe Wizard

```
  ┌──────────────────────────────────────────────────────────────────┐
  │                    CREATE RECIPE WIZARD                          │
  │                                                                  │
  │  ┌──────────┐  Next  ┌──────────┐  Next  ┌──────────┐          │
  │  │ Step 1   │──────▶│ Step 2   │──────▶│ Step 3   │          │
  │  │ Name &   │       │Ingredients│       │  Steps   │          │
  │  │ Photo    │◄──────│          │◄──────│          │          │
  │  │          │  Back  │ add/remove│  Back │ StepRow  │          │
  │  │recipeName│       │  rows    │       │ text +   │          │
  │  │emoji     │       │ ≥1 req'd │       │ timer    │          │
  │  │tagline   │       │          │       │ ≥1 req'd │          │
  │  └──────────┘       └──────────┘       └─────┬────┘          │
  │                                               │ Next          │
  │                                               ▼               │
  │                     ┌──────────┐  Next  ┌──────────┐          │
  │                     │ Step 5   │◄──────│ Step 4   │          │
  │                     │ Review   │       │ Details  │          │
  │                     │ (read-   │──────▶│          │          │
  │                     │  only)   │  Back  │cookTime  │          │
  │                     │          │       │servings  │          │
  │                     └────┬─────┘       │difficulty│          │
  │                     Save │             │cuisine   │          │
  │                          ▼             └──────────┘          │
  │                  ┌──────────────┐                             │
  │                  │UserDataService│                             │
  │                  │saveUserRecipe │                             │
  │                  │isUserCreated  │                             │
  │                  │  = true       │                             │
  │                  └──┬────────┬──┘                             │
  │              success│        │error                           │
  │                     ▼        ▼                                │
  │            Sheet dismissed  saveError shown                   │
  │            Journey refreshes   (retry)                        │
  └──────────────────────────────────────────────────────────────┘
```

---

## 17. Theme System

```
  ┌────────────────────────────────────────────────────────────────────┐
  │                        THEME SYSTEM                                │
  │                                                                    │
  │                  ┌────────────────────┐                             │
  │                  │  AppTheme protocol │                             │
  │                  │  (color tokens +   │                             │
  │                  │   corner radii)    │                             │
  │                  └───┬──────────┬─────┘                            │
  │                      │          │                                   │
  │                      ▼          ▼                                   │
  │              ┌────────────┐  ┌────────────┐                        │
  │              │ LightTheme │  │ DarkTheme  │                        │
  │              └──────┬─────┘  └──────┬─────┘                        │
  │                     │               │                              │
  │                     └───────┬───────┘                              │
  │                             │                                      │
  │               ┌─────────────┼────────────────┐                     │
  │               ▼                              ▼                     │
  │     ┌──────────────────┐           ┌──────────────────┐            │
  │     │   SystemTheme    │           │ @Environment     │            │
  │     │ (wraps based on  │           │ appTheme         │            │
  │     │  colorScheme)    │──────────▶│ injected at root │            │
  │     └──────────────────┘           └────────┬─────────┘            │
  │                                             │                      │
  │                                             ▼                      │
  │                                     ┌──────────────┐               │
  │                                     │ SwiftUI Views│               │
  │                                     └──────────────┘               │
  │                                                                    │
  │  Color Tokens (20):                                                │
  │    bg · surface · surfaceLight · card · accent · accentSoft        │
  │    mint · mintSoft · rose · roseSoft · lavender · lavenderSoft     │
  │    sky · skySoft · gold · text1 · text2 · text3 · divider          │
  │                                                                    │
  │  Corner Radii: small=12 · medium=16 · large=20 · XL=24 · pill=32  │
  │                                                                    │
  │  ViewModifiers: .frostCard() · .neonGlow(_:radius:) · .sectionLabel()│
  │  UIConstants:   54 fonts · 7 animations · spacing/padding          │
  │  Strings:       localized per screen (String Catalog, Xcode 15+)   │
  │  Icons:         SF Symbols per screen                              │
  └────────────────────────────────────────────────────────────────────┘
```

---

## 18. Build Configuration Matrix

| Runtime | LLM / AI | Recipe API | Auth | Subscription | Database |
|---------|----------|------------|------|--------------|----------|
| Normal DEBUG + Supabase keys | `SupabaseLLMProvider` through `SupabaseServiceAssembly` | `SupabaseRecipeAPIProvider` | `SupabaseAuthService` | `MockSubscriptionService` | `DatabaseInitializationService` |
| Normal DEBUG + no Supabase keys | unavailable (`AIService` has nil provider) | offline only | `MockAuthService` | `MockSubscriptionService` | `DatabaseInitializationService` |
| UI Testing DEBUG | `MockLLMProvider` | offline only (`OnlineRecipeSource(provider: nil)`) | `MockAuthService` | `MockSubscriptionService` from launch args | in-memory DB + `UITestDataSeeder` |
| RELEASE + Supabase keys | `SupabaseLLMProvider` through `SupabaseServiceAssembly` | `SupabaseRecipeAPIProvider` | `SupabaseAuthService` | `StoreKitSubscriptionService` | `DatabaseInitializationService` |
| RELEASE + no Supabase keys | unavailable (`AIService` has nil provider) | offline only | `NoOpAuthService` | `StoreKitSubscriptionService` | `DatabaseInitializationService` |

API keys come from gitignored `Support/APIKeys.plist` placeholders: `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Legacy direct-provider keys still exist in code/config readers but are not used by active app wiring.

**UI Test launch arguments** parsed by `UITestConfiguration` (DEBUG-only):

| Argument | Effect |
|----------|--------|
| `--uitesting` | enables deterministic bootstrapping |
| `--skip-onboarding` | skips onboarding unless paired with `--fresh-install` |
| `--fresh-install` | forces first-launch onboarding |
| `--premium-user` | `MockSubscriptionService` starts as `.premium` |
| `--with-cooking-history` | seeds deterministic `cooking_sessions` |
| `--with-favorites` | seeds `favorite_recipes` |
| `--with-shopping-items` | seeds `shopping_items` |
| `--empty-db` | skips all DB seeding |
| `--large-dataset` | seeds larger deterministic recipe set |
| `--camera-limit-reached` | preloads `CameraScanTracker` to weekly cap |
| `--signed-in-apple` | `MockAuthService` starts as Apple-authenticated |

---

## 19. ViewModel State Summary

```
┌─────────────────────────────────────────────────────────────────────────┐
│ DiscoverViewModel (21 @Published)                                      │
│ selectedIngredients · selectedMood · searchText · selectedCategory      │
│ popularIngredients · recentRecipes · savedRecipes · searchResultRecipes │
│ isSearching · searchError · homeLoadError · isLoadingIngredients        │
│ showResults · useItAllFilter · suggestedRecipes · suggestionReason      │
│ activeDietaryRestrictions · collections · loadingCollectionID           │
│ isMatchInfoPopoverPresented · shownIngredients                          │
│ Services: IngredientsServ, RecipeServ, UserDataServ, SubscriptionServ, │
│   DatabaseInitServ, CameraScanTracker, RecommendationServ,             │
│   AnalyticsServ, DietaryPrefs, CuratedCollectionServ                   │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ JourneyViewModel (17 @Published)                                       │
│ recipesCooked · dayStreak · hoursCooking · uniqueIngredientsUsed       │
│ monthlyRecipesCooked · monthlyIngredientsRescued                       │
│ savedRecipes · userRecipes · weekCookingDates                          │
│ achievements · isAchievementsExpanded · recentSessions                  │
│ isLoading · cookAgainErrorMessage · errorMessage                        │
│ isAnonymous · isSigningIn                                               │
│ Services: UserDataServ, SubscriptionServ, CameraScanTracker,           │
│   AuthServ, SignInWithAppleAction, Logger                              │
└─────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────┐  ┌──────────────────────────────────────┐
│ RecipeDetailsVM (4 @Pub)      │  │ CookModeVM (6 @Pub)                 │
│ recipe · isFavorite ·         │  │ currentStep · timerSeconds ·        │
│ isLoadingFavorite · errorMsg  │  │ timerRunning · completedSteps ·     │
│ Svc: UserData, ShoppingList,  │  │ showFeedback · feedbackRating       │
│   Subscription, Analytics     │  │ Svc: UserData, Analytics            │
└───────────────────────────────┘  └──────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ CreateRecipeViewModel (13 @Published)                                  │
│ currentStep · recipeName · selectedEmoji · tagline                      │
│ ingredientRows · stepRows                                              │
│ cookTimeMinutes · servings · difficulty · cuisine                       │
│ isSaving · saveError · didSave                                         │
│ Services: UserDataServ                                                  │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ SettingsViewModel (15 @Published)                                      │
│ currentPlan · authState · isAnonymous · themePreference                 │
│ recipeCount · favoriteCount · recentRecipeCount                        │
│ isLoading · isRestoringPurchases · restoreError · errorMessage          │
│ showClearRecentAlert · showClearFavoritesAlert                          │
│ isSigningIn · showSignOutConfirmation                                   │
│ Svc: UserData, DBInterface, Subscription, DietaryPrefs, Auth, Analytics│
└─────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────┐  ┌──────────────────────────────────────┐
│ OnboardingVM (2 @Pub)         │  │ ShoppingListVM (3 @Pub)             │
│ currentPage · cameraState     │  │ items · isLoading · errorMessage    │
│ CameraPageState: idle ·       │  │ groupedItems (computed)             │
│  requestingPermission ·       │  │ Svc: ShoppingListServ               │
│  permissionGranted · capturing│  └──────────────────────────────────────┘
│  · processing · detected ·    │
│  noIngredientsFound · error · │  ┌──────────────────────────────────────┐
│  permissionDenied             │  │ CameraVM (2 @Pub)                   │
│ Svc: IngredientDetection,     │  │ state · detectedIngredients         │
│  CameraScanTracker, Analytics │  │ State: requestingPermission ·       │
└───────────────────────────────┘  │  permissionDenied · capturing ·     │
                                    │  processing · noIngredientsFound ·  │
┌───────────────────────────────┐  │  error                              │
│ UpgradeVM (5 @Pub)            │  │ Svc: IngredientDetection            │
│ currentPlan · isLoading ·     │  └──────────────────────────────────────┘
│ purchaseError · showErrorAlert│
│ priceByPlan                   │  ┌──────────────────────────────────────┐
│ Svc: Subscription, Analytics  │  │ RecipeListVM (2 @Pub)               │
└───────────────────────────────┘  │ recipes · savedIds                  │
                                    │ Svc: UserDataServ                   │
                                    └──────────────────────────────────────┘
```

**ViewModel @Published count summary:**

| ViewModel | @Published Properties | Key Services |
|-----------|-----------------------|-------------|
| `DiscoverViewModel` | 21 | IngredientsService, RecipeService, UserDataService, SubscriptionService, CameraScanTracker, RecommendationService, AnalyticsService, DietaryPreferences, CuratedCollectionService, DatabaseInitService |
| `JourneyViewModel` | 17 | UserDataService, SubscriptionService, CameraScanTracker, AuthService, SignInWithAppleAction, Logger |
| `RecipeDetailsViewModel` | 4 | UserDataService, ShoppingListService, SubscriptionService, AnalyticsService |
| `CookModeViewModel` | 6 | UserDataService, AnalyticsService |
| `CreateRecipeViewModel` | 13 | UserDataService |
| `SettingsViewModel` | 15 | UserDataService, DBInterface, SubscriptionService, DietaryPreferences, AuthService, AnalyticsService, SignInWithAppleAction |
| `OnboardingViewModel` | 2 | IngredientDetectionService, CameraScanTracker, AnalyticsService |
| `ShoppingListViewModel` | 3 | ShoppingListService |
| `CameraViewModel` | 2 | IngredientDetectionService |
| `UpgradeViewModel` | 5 | SubscriptionService, AnalyticsService |
| `RecipeListViewModel` | 2 | UserDataService |
