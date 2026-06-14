---
paths:
  - "CookSavvyTests/**"
---

# Unit & Integration Tests

## File Map

```
CookSavvyTests/
├── Mocks/
│   ├── MockServices.swift              — MockDatabaseInitService, MockIngredientsService, MockRecipeService, MockPantryService, MockRecommendationService, MockCameraScanTracker, MockImageService
│   ├── MockSupabaseClientProvider.swift
│   ├── MockUserDataService.swift
│   └── MockShoppingListService.swift
├── SupabaseConfigurationTests.swift
├── SupabaseProviderTests.swift
├── SupabaseServiceAssemblyTests.swift
├── AsyncValueBroadcasterTests.swift     — AsyncValueBroadcaster replay/fan-out/ordering (Combine→AsyncStream primitive)
├── CookSavvyTests.swift                — DBInterface integration tests
├── IngredientsServiceTests.swift
├── RecipeServiceTests.swift
├── ImageServiceTests.swift
├── OfflineRecipeSourceTests.swift
├── OnlineAndAIRecipeSourceTests.swift
├── RecipeSourceTests.swift
├── RecipeDatasetReaderTests.swift
├── RecipeMoodRankerTests.swift
├── RecipeMatchRankerTests.swift
├── RecipeRecommendationServiceTests.swift
├── CameraScanTrackerTests.swift
├── ShoppingListServiceTests.swift
├── AchievementEvaluatorTests.swift
├── URLBuilderTests.swift
├── NetworkServiceTests.swift
├── IngredientTests.swift
├── RecipeModelTests.swift
├── UserDataServiceTests.swift
├── DiscoverViewModelTests.swift
├── JourneyViewModelTests.swift
├── CookModeViewModelTests.swift
├── CreateRecipeViewModelTests.swift
├── ShoppingListViewModelTests.swift
├── RecipeDetailsViewModelTests.swift
└── SettingsViewModelAuthTests.swift
```
