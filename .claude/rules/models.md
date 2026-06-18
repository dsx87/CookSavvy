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
├── IngredientEmojiProvider.swift  — Static emoji resolution (exact→contains→word→foodGroup→default)
├── CookingSession.swift           — Cooking session tracking
├── Achievement.swift              — Achievement definitions (7 achievements)
└── SubscriptionPlan.swift
```
