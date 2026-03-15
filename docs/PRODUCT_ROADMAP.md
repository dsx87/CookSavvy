# CookSavvy Product Roadmap

> **Author:** Senior PM Review (March 2026)
> **Status:** Active
> **Target Users:** Beginners, busy people, food-waste-conscious home cooks
> **Monetization:** Subscription (CookSavvy+)
> **Release Gate:** After Phase 3 (requires simple backend for API keys)
> **Scope:** 5 phases — Phases 1-3 are pre-launch, Phase 4+ is post-launch iteration

---

## Current State Assessment

### What's Strong

| Area | Rating | Notes |
|------|--------|-------|
| Architecture | 9/10 | Clean MVVM + Coordinator, protocol-driven, DI container |
| Services Layer | 9/10 | Recipe, Image, Ingredients, DB, Network all production-ready |
| UI Completeness | 9/10 | All 12 screens fully implemented, no stubs |
| Visual Polish | 9/10 | Theme system, animations, gradients, frost effects |
| Error Types | 9/10 | Typed errors at every layer with LocalizedError |
| Subscription System | 9/10 | StoreKit 2 complete, feature gating, scan tracking |
| Database | 9/10 | GRDB with FTS5 indexes, 12 tables, proper schema |
| Test Coverage | 7/10 | Core services tested, ViewModels tested, gaps in network/AI tests |

### What's Broken or Missing

| Problem | Severity | Impact |
|---------|----------|--------|
| Core value prop (camera) behind paywall | CRITICAL | Free users never experience differentiator → low conversion |
| No product identity in UI | HIGH | App looks generic; no anti-waste framing or unique voice |
| AIRecipeSource not implemented | HIGH | Advertised feature doesn't work |
| No analytics/telemetry | HIGH | Blind to user behavior, retention, conversion |
| Accessibility | HIGH | Dynamic Type missing, no high contrast, minimal VoiceOver |
| Silent network errors | MEDIUM | Users can't tell if search failed or returned 0 results |
| No dietary preferences/allergies | MEDIUM | Table stakes for recipe apps — missing entirely |
| No recipe images for 20k offline recipes | MEDIUM | Recipe app without food photos |
| No personalized recommendations | MEDIUM | Data exists (history, favorites) but unused |
| No post-cook feedback loop | MEDIUM | Ratings collected but not used to improve suggestions |
| No recipe sharing | LOW | Missing organic growth channel |
| Singleton DI pattern | LOW | Technical debt, low urgency |

---

## Open Questions

> These assumptions shape the roadmap. Adjust phases if answers differ.

| # | Question | Answer |
|---|----------|--------|
| 1 | **Target audience** | Beginners, busy people, and food-waste-conscious users |
| 2 | **Revenue model** | Hobby project with subscription monetization (CookSavvy+) |
| 3 | **Pricing** | Current $0.99/month won't cover API costs — raise to $2.99/month or $19.99/year when value justifies it |
| 4 | **Dataset quality** | Needs audit for duplicates, low-quality entries, offensive content |
| 5 | **Localization** | English only for now; localization in Phase 4+ |
| 6 | **App Store** | Pre-launch; roadmap includes a Release milestone |
| 7 | **Timeline** | Not time-bound; organized by big steps and directions |
| 8 | **Backend** | Simple backend needed before release to cache/store API keys (no keys in the app binary) |

---

## Phase 1: Product Identity & Core Loop (Weeks 1-6)

**Goal:** Fix the fundamental product-market fit issues. Make the free experience compelling and the paid upgrade feel earned.

### 1.1 — Unlock Camera for Free Users

**Problem:** Free users are stuck on a manual ingredient grid (identical to every competitor). They never experience what makes CookSavvy different.

**What to do:**
- Free users get 5 camera scans per week (already tracked via `CameraScanTracker`)
- Show remaining scan count in camera UI ("3 of 5 scans left this week")
- When limit hit → show upgrade prompt with copy: "Loved scanning? Go unlimited with CookSavvy+"
- Remove `cameraIngredientDetection` from `PaidFeature` gating; replace with scan-limit check

**Why this matters:** Users must experience the differentiator before they'll pay. The current flow is: download → see generic grid → leave. The new flow is: download → scan fridge → get recipes → hit limit → understand value → upgrade.

**Files involved:** `CameraScanTracker.swift`, `CameraViewModel.swift`, `UpgradeView.swift`, `PaidFeature` enum

### 1.2 — Anti-Waste Identity Throughout UI

**Problem:** The app says "use what you have" in its positioning but the UI is generic. No copy, framing, or features reinforce this identity. The three target audiences (beginners, busy people, food waste) aren't addressed in the UX.

**What to do:**
- Discover greeting: Replace generic "Good Morning" → "What do you need to use up?" (waste-conscious framing)
- Add "Use It All" toggle/filter that prioritizes recipes using ALL selected ingredients (infrastructure exists in `OfflineRecipeSource` match percentage)
- Rename match percentage label to something human: "Uses 8 of 10 ingredients" instead of "80% match"
- Subtle waste-reduction framing in empty states: "Scan your fridge to rescue those ingredients"
- Beginner-friendly recipe indicators: complexity badges ("Easy", "Quick", "Beginner-Friendly") prominently shown
- Busy-person framing: Show cooking time prominently; default sort by quickest when no mood selected
- Consider "Quick & Easy" as default mood filter for first-time users

**Files involved:** `DiscoverView.swift`, `DiscoverViewModel.swift`, `DiscoverComponents.swift`, `Strings.swift`, `RecipeMoodRanker.swift`

### 1.3 — Fix Silent Network Errors

**Problem:** Recipe search silently swallows errors (`catch {}`). Users can't tell if a search failed or genuinely returned zero results.

**What to do:**
- Show inline error banner when online/AI sources fail: "Online recipes unavailable — showing local results"
- Add retry button for network errors
- Distinguish "no results" (show suggestions) from "error" (show retry)

**Files involved:** `DiscoverViewModel.swift`, `DiscoverView.swift`, `RecipeService.swift`

### 1.4 — Connect AIRecipeSource

**Problem:** `AIRecipeSource` is stubbed (returns `.sourceUnavailable`). The `AIService.generateRecipes()` method is fully implemented but not wired up.

**What to do:**
- Implement `AIRecipeSource.fetchRecipes()` to call `AIService.generateRecipes()`
- Implement `AIRecipeSource.isAvailable` to check for configured LLM provider
- Add unit tests for AIRecipeSource
- Verify end-to-end flow: ingredient selection → AI source → recipe results

**Files involved:** `AIRecipeSource.swift`, `AIService.swift`, `AppContainer.swift`

### 1.5 — Dietary Preferences & Allergies (Basic)

**Problem:** Table stakes for any recipe app. Users with allergies or dietary restrictions can't filter results.

**What to do:**
- Add dietary profile to Settings: vegetarian, vegan, gluten-free, dairy-free, nut-free, halal, kosher
- Store in UserDefaults (simple key-value, no DB migration needed)
- Filter recipe results post-fetch (client-side filtering on `Recipe.cleanedIngredients` and `Recipe.additionalInfo`)
- Show active filters as pills on Discover screen

**Files involved:** New `DietaryPreferences` model, `SettingsView.swift`, `SettingsViewModel.swift`, `DiscoverViewModel.swift`, `RecipeService.swift`

### 1.6 — Analytics Foundation

**Problem:** No telemetry at all. You're building blind — no data on retention, conversion, feature usage, or drop-off points.

**What to do:**
- Integrate a lightweight analytics SDK (TelemetryDeck recommended — privacy-focused, SwiftUI-native, free tier available)
- Track key events:
  - `app_opened`, `onboarding_completed`, `onboarding_skipped`
  - `camera_scan_started`, `camera_scan_succeeded`, `camera_scan_failed`
  - `recipe_search_performed` (with source: offline/online/AI)
  - `recipe_viewed`, `recipe_favorited`, `recipe_cooked`
  - `upgrade_screen_viewed`, `upgrade_purchased`, `upgrade_dismissed`
  - `scan_limit_hit`
- Define behind a protocol (`AnalyticsServiceProtocol`) for consistency with existing architecture

**Files involved:** New `AnalyticsService`, `AppContainer.swift`, key ViewModels

---

## Phase 2: Retention & Depth (Weeks 7-12)

**Goal:** Give users reasons to come back daily. Build the habit loop: scan → cook → rate → get better suggestions.

### 2.1 — Post-Cook Feedback Loop

**Problem:** Cook Mode tracks duration but never asks the user how it went. Cooking sessions are logged but the data isn't used.

**What to do:**
- After Cook Mode completion, show a 1-screen feedback overlay:
  - "How was it?" → 1-5 star rating (already in CookingSession model)
  - "Would you make this again?" → Yes / No toggle
  - "Quick note?" → Optional one-line text field
- Store `wouldMakeAgain` and `note` in `cooking_sessions` table (DB migration needed)
- Use rating data to weight recipe ranking in future searches
- Surface top-rated recipes in a "Your Favorites" section

**Files involved:** `CookModeView.swift`, `CookModeViewModel.swift`, `CookingSession.swift`, `DBInterface.swift`, `RecipeService.swift`

### 2.2 — Personalized Recommendations

**Problem:** The app tracks cooking history and favorites but never uses this data to suggest recipes. `RecipeRecommendationService` exists but isn't surfaced.

**What to do:**
- Add "Suggested for You" section to Discover (above recipe results)
- Recommendation signals:
  - Frequently used ingredients → suggest recipes with those ingredients
  - Frequently cooked cuisines → suggest same cuisine
  - Favorited recipes → suggest similar (shared ingredients/cuisine)
  - Time of day → quick recipes in morning, comfort food in evening
- Show 3-5 recommendation cards with explanation: "Because you love Italian" or "Uses your frequent ingredients"

**Files involved:** `RecipeRecommendationService.swift`, `DiscoverView.swift`, `DiscoverViewModel.swift`, `DiscoverComponents.swift`

### 2.3 — Recipe Placeholder Images

**Problem:** 20,000 offline recipes have no visible images. A recipe app without food photos is severely handicapped.

**What to do:**
- Generate attractive gradient cards as placeholders:
  - Background: gradient based on cuisine type (warm tones for Italian, cool for Japanese, etc.)
  - Center: large emoji from `Recipe.emoji`
  - Bottom: recipe title
- Map cuisine → gradient color pairs in theme system
- This is a visual-only change — no data model changes needed

**Alternative (higher effort):** Use AI image generation for top 200-500 most-viewed recipes. Batch job, not real-time.

**Files involved:** `RecipeCardComponents.swift` (RecipeImage), `AppTheme.swift`, `UIConstants.swift`

### 2.4 — Improve Error & Empty States

**Problem:** Some empty states are functional but uninspiring. Error states for network issues are silent.

**What to do:**
- Empty Discover (no ingredients selected): Show illustration + "Scan your fridge or pick ingredients below"
- Empty search results: Show "No recipes match — try removing an ingredient" with suggestions
- Network error: Inline banner with retry, not silent failure
- Camera permission denied: More compelling copy with visual guide

**Files involved:** `DiscoverView.swift`, `DiscoverComponents.swift`, `CameraView.swift`

### 2.5 — Shopping List Enhancements

**Problem:** Shopping list exists but is basic. Missing integration touchpoints.

**What to do:**
- Recipe Detail: Show which ingredients user has vs. needs (match against selected ingredients)
- "Add Missing to Shopping List" button on Recipe Detail (already referenced in CLAUDE.md)
- Group shopping items by category (produce, dairy, etc.) not just recipe
- Export/share shopping list as text
- Badge on Shopping List icon showing item count

**Files involved:** `ShoppingListView.swift`, `ShoppingListViewModel.swift`, `RecipeDetailsView.swift`, `RecipeDetailsViewModel.swift`

---

## Phase 3: Growth & Engagement (Weeks 13-20)

**Goal:** Build features that drive organic growth, increase session frequency, and deliver ongoing subscription value.

### 3.1 — Recipe Sharing

**Problem:** Users can't share recipes. Missing the strongest organic growth channel for a recipe app.

**What to do:**
- Share button on Recipe Detail (iOS ShareLink)
- Generate shareable card image: gradient background + emoji + recipe title + ingredient count + "Made with CookSavvy"
- Share formats: image card (Instagram/social), text (iMessage), link (if deep linking added later)
- User-created recipes: share with full recipe content

**Files involved:** `RecipeDetailsView.swift`, `RecipeDetailsViewModel.swift`, new `ShareCardGenerator` utility

### 3.2 — Curated Collections

**Problem:** After the first week, premium subscribers see diminishing value. No fresh content discovery.

**What to do:**
- Weekly curated collections: "5-Ingredient Dinners", "30-Minute Meals", "Zero Waste Recipes", "Budget Friendly"
- Collections are filter presets over the existing 20k database (no new content needed)
- Show on Discover as horizontal scroll cards
- Rotate weekly based on date seed (deterministic, no backend needed)
- Premium users see all collections; free users see 1

**Files involved:** New `CuratedCollectionService`, `DiscoverView.swift`, `DiscoverViewModel.swift`

### 3.3 — Waste Reduction Stats & Achievements

**Problem:** Anti-waste identity has no metrics. Users can't see their impact.

**What to do:**
- Track: total ingredients used, total recipes cooked, estimated meals produced
- Journey screen: replace generic stats with impact stats
  - "47 ingredients rescued this month"
  - "12 meals cooked from what you had"
- New achievements:
  - "Fridge Cleaner" — cooked 5 recipes using 90%+ match
  - "Zero Waste Week" — cooked every day for a week
  - "Ingredient Master" — used 50 unique ingredients
  - "Scan Pro" — scanned ingredients 20 times
- Monthly summary notification (local): "You rescued 47 ingredients and cooked 12 meals this month!"

**Files involved:** `Achievement.swift`, `JourneyView.swift`, `JourneyViewModel.swift`, `UserDataService.swift`, `Strings.swift`

### 3.4 — Accessibility Pass

**Problem:** Accessibility scored 4/10. Dynamic Type missing, no high contrast support, minimal VoiceOver labels.

**What to do:**
- **Dynamic Type:** Replace all hardcoded font sizes with `@ScaledMetric` or `.dynamicTypeSize()` modifiers
- **VoiceOver:** Add `.accessibilityLabel` to all interactive elements (mood pills, achievement badges, ingredient grid items, recipe cards)
- **High Contrast:** Test and fix all color combinations for WCAG AA contrast
- **Reduce Motion:** Respect `UIAccessibility.isReduceMotionEnabled` for spring animations
- **Semantic grouping:** Add `.accessibilityElement(children: .combine)` for card components
- **Image labels:** Add descriptions to recipe hero images and ingredient icons

**Files involved:** All View files, `AppTheme.swift`, `UIConstants.swift`, `ViewModifiers.swift`

### 3.5 — Improved Mood/Context Ranking

**Problem:** Mood ranking uses hardcoded keyword heuristics. Brittle on a 20k dataset.

**What to do:**
- Pre-compute mood scores for all recipes at import time
- Use LLM batch classification: send recipes in batches of 50-100 to classify mood tags (comfort, quick, healthy, adventurous, light)
- Store mood scores as recipe metadata in DB (new column or JSON field)
- Fall back to keyword heuristic for user-created recipes

**Files involved:** `RecipeMoodRanker.swift`, `Recipe.swift`, `DBInterface.swift`, `DataImportService.swift`

---

---

## RELEASE GATE: App Store Launch Readiness

> **This checkpoint sits between Phase 3 and Phase 4.** The app should be release-ready after completing Phases 1-3. Phase 4+ is post-launch iteration.

### Release Checklist

- [ ] **Simple Backend for API Keys** — Build a lightweight backend (e.g., Vapor, CloudFlare Worker, or simple AWS Lambda) that:
  - Stores API keys server-side (OpenAI, Gemini, Spoonacular) — never ship keys in the app binary
  - Proxies or vends short-lived tokens to the app
  - Rate-limits per user/device to prevent abuse
  - Requires minimal infrastructure (serverless preferred)
  - Update `APIKeyConfiguration` to fetch keys from backend instead of `APIKeys.plist`
  - Update `NetworkConfiguration` to route API calls through backend proxy (or fetch keys on app launch)
- [ ] **App Store Assets** — Screenshots, description, keywords aligned with "scan your fridge → cook what you have" positioning
- [ ] **Privacy Policy & Terms** — Required for App Store; must cover camera usage, AI processing, analytics
- [ ] **App Review Prep** — Test all subscription flows, ensure camera permission dialogs have proper descriptions, verify StoreKit configuration
- [ ] **Crash Reporting** — Integrate lightweight crash reporting (TelemetryDeck can do this, or Sentry free tier)
- [ ] **Final QA Pass** — Test on iPhone SE (small screen), iPhone 15 Pro Max (large screen), and at least one older iOS version

---

## Phase 4: Post-Launch Iteration

**Goal:** Optimize based on real user data. Subscription tuning, performance, and expanding content.

### 4.1 — Dataset Audit & Quality

**What to do:**
- Audit 20k recipes for: duplicates, missing fields, offensive/inappropriate content, broken instructions
- Remove or fix low-quality entries
- Normalize cuisine tags (inconsistent casing, synonyms)
- Add missing metadata where possible (calories from Spoonacular when `addRecipeNutrition=true`)

### 4.2 — Subscription Optimization

**What to do:**
- A/B test pricing: $2.99/month vs $3.99/month vs $19.99/year vs $29.99/year
- Add annual plan option (StoreKit 2 supports multiple products)
- Implement free trial (7-day) for premium
- Paywall optimization: test different upgrade screen copy/layouts
- Track conversion funnel: scan limit hit → upgrade viewed → purchased

**Files involved:** `UpgradeView.swift`, `UpgradeViewModel.swift`, `StoreKitSubscriptionService.swift`, `Configuration.storekit`

### 4.3 — Onboarding Optimization

**What to do:**
- Make onboarding camera-first: first screen should let user scan (not just show illustration)
- Collect dietary preferences during onboarding (from Phase 1.5)
- Track completion rate and drop-off screen (from Phase 1.6 analytics)
- Consider skippable but compelling flow (don't gate app behind 3 screens)

**Files involved:** `OnboardingView.swift`, `OnboardingViewModel.swift`

### 4.4 — Refactor DI Away from Singleton

**What to do:**
- Replace `AppContainer` singleton with proper dependency injection
- Options: SwiftUI `@Environment`, Swinject, or manual constructor injection
- Improves testability and removes global mutable state
- Low urgency but prevents tech debt from compounding

**Files involved:** `AppContainer.swift`, all Coordinators, `CookSavvyApp.swift`

### 4.5 — Expanded Test Coverage

**What to do:**
- Add explicit NetworkService tests (currently only implicit via provider tests)
- Add AIService integration tests (with MockLLMProvider)
- Add AIRecipeSource tests (after Phase 1.4 implementation)
- Add UI tests for critical flows: onboarding, camera scan, cook mode completion
- Target: 80%+ code coverage on services layer

### 4.6 — Performance & Reliability

**What to do:**
- Profile app launch time (target < 2 seconds to interactive)
- Optimize DataImportService (TODO at line 60)
- Add crash reporting (Sentry or Firebase Crashlytics)
- Memory profiling for image cache (currently 50MB limit — verify under pressure)
- Background fetch for recipe updates (if online sources active)

---

## Phase 5: Future Opportunities (Beyond Week 30)

These are not committed but worth tracking as potential directions based on user feedback and analytics.

### 5.1 — Social Features
- Follow friends, share cooking activity
- Community recipe collections
- "Cooked it" social proof on recipes

### 5.2 — Meal Planning
- Weekly meal planner with drag-and-drop
- Auto-generate shopping list from meal plan
- Nutritional tracking across the week

### 5.3 — Smart Pantry
- Persistent ingredient inventory (not just per-search)
- Expiration date tracking with push notifications
- "Use soon" priority in recipe suggestions
- Barcode scanning for packaged ingredients

### 5.4 — Cooking Assistant
- Voice-guided cook mode (Siri integration or TTS)
- Step-by-step timer chaining (finish step 3 → auto-start step 4 timer)
- Video instructions (sourced or AI-generated)

### 5.5 — Multi-Platform
- iPad companion app (split view: recipe + timer)
- watchOS timer companion
- macOS Catalyst for recipe browsing

### 5.6 — Localization
- Multi-language support via String Catalog
- Region-specific recipe datasets
- Metric/imperial unit toggle

### 5.7 — Widget & Live Activities
- Home screen widget: "Tonight's suggestion" based on recent ingredients
- Lock screen widget: remaining camera scans this week
- Live Activity during cook mode (timer on lock screen)

---

## Priority Matrix

```
                        HIGH IMPACT
                            |
        Phase 1.1           |          Phase 2.2
        (Camera for free)   |          (Recommendations)
                            |
        Phase 1.2           |          Phase 3.1
        (Anti-waste ID)     |          (Sharing)
                            |
  LOW EFFORT ---------------+--------------- HIGH EFFORT
                            |
        Phase 1.3           |          Phase 3.4
        (Fix errors)        |          (Accessibility)
                            |
        Phase 2.3           |          Phase 4.1
        (Placeholder imgs)  |          (Dataset audit)
                            |
                        LOW IMPACT
```

## Implementation Notes for LLM Agents

Each phase item above is designed to be independently implementable. When delegating to an LLM:

1. **Always reference CLAUDE.md** — it contains architecture rules, code style, project structure, and theme system details that must be followed
2. **One feature per conversation** — don't batch multiple phase items; each is a discrete unit of work
3. **Read before writing** — every item lists "Files involved." The LLM should read those files first to understand current implementation
4. **Follow existing patterns** — the codebase has strong conventions (protocols for services, coordinators for navigation, `Strings` for copy, `UI` for constants). New code must match
5. **Update CLAUDE.md** — after structural changes (new services, screens, models), update CLAUDE.md to reflect the new state
6. **Tests** — every new service needs tests. Every new ViewModel should have basic tests. Use existing mock patterns
7. **No over-engineering** — these are scoped features. Implement what's described, nothing more

---

## Success Metrics

| Metric | Current | Phase 1 Target | Phase 3 Target |
|--------|---------|----------------|----------------|
| Day 1 retention | Unknown | 40% | 50% |
| Day 7 retention | Unknown | 20% | 30% |
| Free → Premium conversion | Unknown | 3% | 5% |
| Avg sessions/week | Unknown | 3 | 5 |
| Recipes cooked/user/week | Unknown | 1 | 2 |
| Camera scans/user/week | Unknown | 2 | 4 |
| App Store rating | N/A | 4.0+ | 4.5+ |

> All metrics require analytics (Phase 1.6) before they can be tracked.

---

## Revision History

| Date | Change |
|------|--------|
| 2026-03-15 | Initial roadmap created from full codebase audit |
