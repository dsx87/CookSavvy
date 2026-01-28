# CookSavvy — Agent Instructions

> For detailed project documentation, see `CLAUDE.md`

## Quick Reference

**Project:** iOS recipe app (Swift + SwiftUI)  
**Purpose:** Suggest recipes from user-provided ingredients

## Must Follow

### Architecture
- **MVVM pattern** — Views hold only `viewModel`, all state lives in ViewModel
- **Single Responsibility Principle** — create services as needed
- **SwiftUI first** — UIKit only when unavoidable
- **Apple frameworks preferred**

### Code Standards
- **No code duplication** — search existing code before writing new
- Refactor only when necessary; prefer new methods over modifying existing
- Duplication requires explicit user approval

### Workflow
- Ask for clarification before coding if info is missing
- No comments unless instructed (levels: `none` | `needed only` | `every line`)

## Subscription Tiers

| Tier | Recipes | Photo AI |
|------|---------|----------|
| Free | Local DB | ❌ |
| API | REST API | ✅ |
| AI | AI-generated | ✅ |

## Screens

- **Ingredients Input** — text + autocomplete, camera (paid), recent
- **Search Results** — recipe list (name, image, complexity, time)
- **Recipe Details** — full recipe info
- **Recent/Favorites** — same layout as search results
- **Settings** — subscription, limits
