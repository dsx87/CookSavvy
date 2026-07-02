---
paths:
  - "CookSavvy/Models/**"
---

# Models

## File Map

```
Models/
├── ShoppingItem.swift             — Shopping list item (id, name, isChecked, addedAt, recipeTitle)
├── Recipe.swift                   — Recipe + Recipe.Step + AdditionalInfo
├── Ingredient.swift               — Ingredient + IngredientCategory enum (category derived via classifier below)
├── IngredientCategoryClassifier.swift — Name→IngredientCategory keyword classifier (dataset has no food_group)
├── PantryStaples.swift            — Pantry-staple/seasoning set loaded from bundled Support/Assets/Seasonings.json (salt, pepper, oils, dried spices…); single source of truth, hidden from the picker (IngredientsService/UserDataService) AND auto-assumed in matching (RecipeMatchExplainer)
├── PopularIngredients.swift       — Curated, ordered seed (name+emoji) for the Discover "POPULAR" quick-pick grid; UserDataService.getPopularIngredients *blends* it (staples excluded) under the user's recently-selected ingredients (recents lead, seed fills the rest). Sized to UI.Discover.popularIngredientCount (the deferred move-to-front cap in DiscoverViewModel)
├── IngredientEmojiProvider.swift  — Static emoji resolution (exact→contains→word→foodGroup→default)
├── CookingSession.swift           — Cooking session tracking
├── Achievement.swift              — Achievement definitions (7 achievements)
└── SubscriptionPlan.swift
```
