# CookSavvy Product Analysis

**Date:** 2026-03-13
**Author:** Senior PM review (Claude)
**Status:** Actionable recommendations — ready for implementation planning

---

## Product Context

- **Target audience:** Cooking beginners, people who want to reduce food waste
- **Core positioning:** "Make a photo of your ingredients, get recipes. Fast and easy."
- **Revenue model:** Subscription (primary)
- **Content strategy:** 20k bundled offline recipes (long-term), curated collections for subscribers
- **Competitive angle:** Photo → recipes speed/simplicity vs. Supercook, Mealime, YouTube

---

## CRITICAL MISALIGNMENT: Core Value Prop Is Behind the Paywall

**The single biggest product problem.**

CookSavvy's differentiator is "snap a photo → get recipes instantly." But the photo/camera feature requires a paid subscription (`PaidFeature.cameraIngredientDetection`). Free users get a manual ingredient selection grid — which is what every other recipe app offers.

**Impact:** Free users never experience what makes CookSavvy special. They have no reason to believe the paid version is worth it. The conversion funnel is broken at the top — users can't taste the value before paying.

**Current flow (broken):**
```
Free user → manual ingredient grid → generic recipe results → no differentiation → churn
```

**Required flow:**
```
Free user → photo scan (limited) → instant recipes → hits limit → understands value → upgrades
```

---

## Issue #1: Restructure Free/Paid Split

### Problem
Free users can't use the camera. The core value prop ("photo → recipes") is invisible to them. The manual ingredient grid is slow, tedious, and undifferentiated.

### Current State
- Free: manual ingredient selection only, offline recipes only
- API tier ($0.99/mo): camera + Spoonacular online recipes
- AI tier ($0.99/mo): camera + online + AI-generated recipes (NOT IMPLEMENTED — throws `.sourceUnavailable`)

### Recommendation
Give free users limited photo scanning (e.g., 3-5 scans per week). Paid tier removes limits and adds depth.

**Proposed 2-tier model:**

| Feature | Free | CookSavvy+ |
|---------|------|------------|
| Photo ingredient scanning | 3-5/week | Unlimited |
| Recipe database | 20k offline | 20k offline + curated collections + online API |
| Dietary filters | None | Full (allergies, restrictions, preferences) |
| Personalized suggestions | None | Weekly, based on cooking history |
| Grocery/shopping list | None | Yes |
| AI recipe generation | None | Yes (when implemented) |

### Implementation Notes
- Remove the AI tier entirely until AI recipe generation is production-ready
- Rename remaining paid tier to human-readable name (CookSavvy+, Pro, Premium)
- Add scan counter to `UserDataService` (resets weekly)
- Show remaining scans in UI to create upgrade awareness
- Gate on scan count, not on feature access boolean

### Files Affected
- `Models/SubscriptionPlan.swift` — collapse 3 tiers to 2
- `Services/Subscription/SubscriptionServiceProtocol.swift` — simplify feature gating
- `Services/Subscription/StoreKitSubscriptionService.swift` — remove AI product ID
- `Services/Subscription/MockSubscriptionService.swift` — update mock
- `Configuration.storekit` — update StoreKit config
- `Views/Camera/CameraViewModel.swift` — add scan limit check instead of hard paywall
- `Views/Upgrade/` — redesign upgrade screen for single tier
- `Views/Settings/` — simplify subscription section

---

## Issue #2: Anti-Waste Identity Is Completely Absent

### Problem
The target audience includes people who want to reduce food waste. But the app has ZERO features, copy, or framing that addresses waste reduction. The word "waste" doesn't appear anywhere in the UI. The Discover greeting is a generic "Good morning!" There's no waste-related tracking, no "use everything" mode, no urgency around expiring ingredients.

### Current State
- Discover greeting: time-based ("Good Morning!", "Good Afternoon!", etc.)
- Ingredient selection: flat grid, no priority/urgency concept
- Recipe matching: ranked by match percentage (how many of your ingredients appear)
- Journey stats: recipes cooked, streak, hours, user recipes — nothing about waste
- Achievements: generic cooking milestones, nothing waste-related

### Recommendation

**A. Reframe Discover copy around anti-waste:**
- Replace generic greetings with action-oriented copy:
  - "What do you need to use up?"
  - "Don't let these go to waste"
  - "Turn leftovers into dinner"
- Subtitle under ingredient selection: "Select ingredients you want to use up"

**B. Add "Use It All" filter/mode:**
- New filter alongside mood filters (Cozy, Fresh, Bold, etc.)
- Prioritizes recipes that use ALL selected ingredients (not just matching some)
- Visual indicator: "Uses all 5 of your ingredients" badge on recipe cards
- This is the anti-waste killer feature — it directly solves "I have these 4 things, find me something that uses all of them"

**C. "Expiring Soon" ingredient tagging (future):**
- When selecting ingredients, let users mark items as "use soon"
- These get priority weighting in recipe ranking
- Optional: push notification reminder "You have tomatoes to use up — here are 3 recipes"

**D. Waste-reduction stats in Journey:**
- "Ingredients used this month: 47"
- "Ingredients saved from waste: 12" (ingredients marked "use soon" that were then used in a cooked recipe)
- These give users a sense of positive impact

**E. Waste-related achievements:**
- "Zero Waste Week" — cooked recipes using all selected ingredients, 7 days straight
- "Fridge Cleaner" — used 20 different ingredients in a week
- "Leftover Hero" — cooked 5 recipes that used all selected ingredients

### Implementation Notes
- Copy changes (A) are low-effort, high-impact — do first
- "Use It All" filter (B) is the strongest feature here — implement after copy
- Expiring tags (C) and waste stats (D) are medium-effort follow-ups
- Achievements (E) require `Achievement.swift` extension + `AchievementEvaluator` updates

### Files Affected
- `Theme/Strings.swift` — update Discover greeting strings
- `Views/Discover/DiscoverComponents.swift` — greeting UI
- `Views/Discover/DiscoverViewModel.swift` — add "Use It All" filter logic
- `Services/Recipe/RecipeMoodRanker.swift` — add "UseAll" ranking mode
- `Models/Achievement.swift` — add waste-related achievements
- `Views/Journey/JourneyViewModel.swift` — add waste stats
- `Services/UserData/UserDataService.swift` — track ingredient usage

---

## Issue #3: Collapse to 2 Subscription Tiers

### Problem
Three tiers (Free / API / AI) named after backend implementation. Users don't know what "API" means. Both paid tiers are $0.99/month — no price differentiation. The AI tier sells a feature that doesn't work (`AIRecipeSource` throws `.sourceUnavailable`).

### Current State
```swift
enum SubscriptionPlan {
    case free   // manual input, offline only
    case api    // camera + Spoonacular ($0.99/mo)
    case ai     // camera + Spoonacular + AI generation ($0.99/mo, NOT WORKING)
}
```

### Recommendation
Collapse to 2 tiers. One free, one paid. Name the paid tier something human (CookSavvy+, Premium, Pro).

```swift
enum SubscriptionPlan {
    case free       // limited photo scans, offline recipes, basic features
    case premium    // unlimited scans, online + curated recipes, dietary filters, grocery list
}
```

**Pricing suggestion:** $2.99-4.99/month or $19.99-29.99/year. $0.99/month is too low for a subscription — it signals low value and doesn't cover API costs (Spoonacular, OpenAI vision).

When AI recipe generation is production-ready, either:
- Add it to the existing premium tier (increases perceived value, drives retention)
- Or introduce a higher tier at that point (with real, working features)

### Implementation Notes
- This is a breaking change for existing subscribers if any exist
- Update StoreKit product IDs
- Simplify all `PaidFeature` checks
- Remove all references to `.api` and `.ai` plan names in UI

---

## Issue #4: No Onboarding Flow

### Problem
App launches directly to an empty Discover tab with a time-based greeting. No explanation of what to do, no demonstration of value, no permission priming for camera. First-session users are confused and likely churn immediately.

### Current State
- `CookSavvyApp.swift` → `TabContainerView` immediately
- No tutorial, no splash, no walkthrough
- Camera permission requested only when user finds and taps the camera button
- Database import runs silently in background

### Recommendation

**3-screen onboarding (first launch only):**

1. **"Snap your ingredients"** — Show camera illustration/animation. Copy: "Take a photo of what's in your fridge. We'll find recipes that use it all."
2. **"Get recipes instantly"** — Show recipe results illustration. Copy: "Matched recipes ranked by what you have. Less waste, more flavor."
3. **"Cook step by step"** — Show cook mode illustration. Copy: "Follow along at your own pace with built-in timers."
4. **CTA: "Let's Cook" → opens camera directly** (not the grid)

**Key principles:**
- Camera-first experience — the first thing a new user does should be the differentiator
- Prime camera permission with context before the system dialog
- Store `hasCompletedOnboarding` in UserDefaults
- Skip for returning users

### Implementation Notes
- New files: `Views/Onboarding/OnboardingView.swift`, `OnboardingViewModel.swift`
- Modify `CookSavvyApp.swift` or `AppCoordinator.swift` to check onboarding state
- 3-4 days of work including design

### Files Affected
- New: `Views/Onboarding/OnboardingView.swift`
- New: `Views/Onboarding/OnboardingViewModel.swift`
- `App/CookSavvyApp.swift` or `Coordinators/AppCoordinator.swift` — conditional flow
- `Theme/Strings.swift` — onboarding copy

---

## Issue #5: No Recipe Images for 20k Offline Recipes

### Problem
The bundled CSV dataset references image names but the images are not rendered for offline recipes. A recipe app without food photos is severely handicapped — especially for beginners who can't visualize dishes by name. Food is inherently visual; images drive engagement, tap-through, and cooking intent.

### Current State
- CSV has `Image_Name` column with values like `"chicken-tikka-masala.jpg"`
- `AsyncImageDisk` component exists for loading images
- Recipe model has `image: String` field
- But offline recipes show no images (or a placeholder) in practice

### Recommendation (pick one or combine)

**Option A: AI-generated images (recommended for quality + brand consistency)**
- Use an image generation API (DALL-E, Midjourney, Stable Diffusion) to batch-generate hero images
- Target: top 500-1000 most-matched recipes (analyze which recipes appear most in search results)
- One-time generation cost, bundle in app or host on CDN
- Consistent visual style = brand identity

**Option B: Free-license image sourcing**
- Source from Unsplash, Pexels, or Wikimedia Commons
- Map to recipes by title/cuisine keyword matching
- Lower quality match but zero generation cost

**Option C: Enhanced placeholder system (minimum viable)**
- Generate attractive gradient cards using: cuisine type + emoji + recipe name
- Example: warm orange gradient + 🍛 + "Chicken Tikka Masala"
- Uses existing `IngredientEmojiProvider` system
- Not as good as photos but much better than blank/broken image states

**Recommendation:** Start with Option C immediately (days, not weeks), pursue Option A for top recipes over time.

### Implementation Notes
- Option C can be done entirely in `RecipeCardComponents.swift` / `RecipeImage` view
- Options A/B require asset pipeline + storage strategy (bundle vs. CDN vs. on-demand)
- Consider lazy image loading with CDN for paid tier (reduces app size)

---

## Issue #6: No Grocery / Shopping List

### Problem
User discovers a recipe matching 4 of 7 ingredients. They want to cook it but need 3 more items. There's no way to capture what they need to buy. They leave the app, forget, and never come back. The grocery list is the bridge between "I found a recipe" and "I cooked it."

### Current State
- Recipe detail shows all ingredients
- No concept of "you have" vs. "you need"
- No shopping/grocery list feature anywhere
- No persistence of "missing ingredients"

### Recommendation

**Recipe Detail: "Missing Ingredients" section**
- Compare recipe ingredients against user's selected ingredients
- Show which ones they have (checkmark) vs. need (shopping cart icon)
- "Add missing to shopping list" button

**Shopping List screen (accessible from tab bar or Journey)**
- Simple checklist: item name + checkbox
- Grouped by recipe or by category (produce, dairy, etc.)
- Persist locally (GRDB)
- Check off items while shopping
- Clear completed / clear all

**This is a premium feature candidate** — free users see missing ingredients, paid users get the shopping list.

### Implementation Notes
- New model: `ShoppingItem` (ingredient name, recipe reference, checked state)
- New service: `ShoppingListService`
- New view: `ShoppingListView` + `ShoppingListViewModel`
- Recipe detail view modification to show have/need split
- Medium effort (~1-2 weeks)

---

## Issue #7: No Post-Cook Feedback Loop

### Problem
After finishing cook mode, the session is saved silently with just a duration. No rating, no "would cook again," no difficulty feedback. The app tracks behavior but never asks for opinion. Without this signal, recipe quality in the 20k dataset is unknowable, and personalization is impossible.

### Current State
```swift
// CookModeViewModel.swift — on finish:
userDataService.markAsCooked(recipe, duration: duration)
// That's it. No prompt, no rating, no feedback.
```

### Recommendation

**Post-cook prompt (1 screen, 5 seconds):**
After "Finish" in cook mode, show a card:
- "How was it?" — thumbs up / thumbs down (required)
- "Would you make this again?" — yes / no (optional)
- "Any notes?" — free text field (optional, collapsed by default)
- "Done" button dismisses

**Data usage:**
- Thumbs up/down feeds a quality score per recipe (surface better recipes first)
- "Would make again" feeds personal recommendations
- Notes are personal — shown to user when they revisit the recipe
- Aggregate ratings could surface "community favorites" in Discover

### Implementation Notes
- Extend `CookingSession` model with `rating: Bool?`, `wouldMakeAgain: Bool?`, `notes: String?`
- New view: post-cook feedback card (inline, not a full screen)
- Modify `CookModeViewModel` finish flow to show feedback before dismiss
- Low effort (~3-5 days)

### Files Affected
- `Models/CookingSession.swift` — add fields
- `Services/Database/DBInterface.swift` — migrate table
- `Views/CookMode/CookModeView.swift` — add feedback step
- `Views/CookMode/CookModeViewModel.swift` — feedback logic

---

## Issue #8: "Journey" Tab Naming and Purpose

### Problem
"Journey" is abstract and doesn't communicate what the tab contains. It's a catch-all for stats, achievements, sessions, user recipes, and settings access. The metaphor doesn't resonate with the target audience (beginners who want to reduce waste).

### Current State
- Tab 2 labeled "Journey"
- Contains: profile header, stats row, user recipes section, weekly calendar, achievements, recent sessions, settings gear

### Recommendation

**Rename to "My Kitchen"** — concrete, relatable, matches mental model.

**Reframe stats around impact** (ties to anti-waste identity):
- "Recipes Cooked" → keep
- New: "Ingredients Used" — total count of ingredients across all cooked recipes
- "Cooking Streak" → keep
- "Hours Cooking" → keep or replace with "Meals Saved" (recipes cooked that matched 80%+ of selected ingredients)

**Consider splitting in future:**
- "My Kitchen" — stats, achievements, activity
- "My Recipes" — user-created recipes, favorites, collections

---

## Issue #9: No Personalized Recommendations

### Problem
The app tracks cooking history, favorites, ingredient usage, cuisines cooked — but never uses this data to suggest anything. Every session starts from zero. This is a missed retention opportunity and a missed subscription value driver.

### Current State
- `UserDataService` stores: cooking sessions, favorites, user recipes
- `RecipeMoodRanker` ranks by keyword matching against mood
- No recommendation engine, no "for you" section

### Recommendation

**Add "Suggested for You" section in Discover (above ingredient grid):**

Signals to use:
- Frequently used ingredients → suggest recipes with those ingredients
- Frequently cooked cuisines → suggest same cuisine, new recipes
- Favorited recipes → suggest similar (shared ingredients, same cuisine/complexity)
- Never-tried cuisines → "Try something new: Thai" (variety nudge)
- Time of day → quick recipes in morning, comfort food in evening

**This is a premium feature** — free users see 1 suggestion, paid see full personalized feed.

### Implementation Notes
- New service: `RecommendationService` (reads from UserDataService, scores recipes)
- Lightweight — no ML needed, rule-based scoring using existing data
- Add "Suggested" section to `DiscoverViewModel`
- Medium effort (~1-2 weeks)

---

## Issue #10: Subscription Value Delivery Over Time

### Problem
Subscriptions require continuous value delivery. After a user explores the expanded recipe catalog and uses camera scanning for a week, what keeps them subscribed in month 2, 3, 6? There's no ongoing content, no evolving experience, no increasing switching cost.

### Current State
- Paid features are static: camera access + more recipes
- No new content delivery mechanism
- No personalization that improves over time
- No social/community features creating lock-in

### Recommendation

**Ongoing value hooks for premium subscribers:**

1. **Curated weekly collections** — "This Week's Anti-Waste Recipes," "5-Ingredient Dinners," seasonal recipes. Can be editorially curated or algorithm-driven. Refreshes weekly.

2. **Personalization that improves over time** — The more you cook, the better suggestions get. This creates switching cost — leaving means losing your taste profile.

3. **Cooking insights** — Monthly summary: "You cooked 12 meals, saved ~$48 vs. takeout, used 34 different ingredients." Reinforces value and anti-waste identity.

4. **Grocery list integration** — Practical utility that becomes part of weekly routine. Hard to leave once habituated.

5. **Future: social features** — Share recipes, follow friends' cooking activity, community recipe collections. Network effects = strongest retention.

### Implementation Priority
Start with curated collections (1) and personalization (2) — these provide the most retention value per engineering effort.

---

## Issue #11: No Recipe Sharing

### Problem
Users create personal recipes but can't share them — not via link, social media, messaging, or AirDrop. Recipe sharing is one of the strongest organic growth channels for cooking apps. "My friend shared a recipe from CookSavvy" is the best possible acquisition funnel.

### Recommendation
- Share sheet on recipe detail (iOS native `ShareLink`)
- Generate shareable deep link or image card
- Image card: recipe photo/emoji + name + ingredient count + "Made with CookSavvy" branding
- Deep link opens recipe in app (or App Store if not installed)

### Implementation Notes
- Use iOS `ShareLink` API (SwiftUI native)
- Generate share image using `ImageRenderer` (iOS 16+)
- Deep links via Universal Links or custom URL scheme
- Low-medium effort (~1 week)

---

## Issue #12: Mood Filtering Is Fragile

### Problem
The mood ranking system (`RecipeMoodRanker`) uses hardcoded keyword lists to score recipes. This works for obvious cases ("soup" = Cozy) but misses nuance, fails on non-English recipe names, and can't handle the 20k dataset diversity well.

### Current State
```swift
// RecipeMoodRanker.swift — example:
// Cozy keywords: ["baked", "broth", "chili", "curry", "noodle", "soup", "stew", "warm"]
// Scoring: 2-3 points per keyword match in title/tagline/cuisine/ingredients
```

### Recommendation (short term)
- Expand keyword lists significantly (audit 20k recipes for coverage)
- Add negative keywords (e.g., "ice cream" should NOT rank high for Cozy)
- Weight ingredient matches lower than title/cuisine matches
- Add a "None" / "All" mood option (no filtering)

### Recommendation (medium term)
- Pre-compute mood scores for all 20k recipes at import time (store in DB)
- Use LLM to batch-classify recipes by mood (one-time job)
- Store as recipe metadata, query directly instead of runtime scoring

---

## Priority Roadmap

### Phase 1: Identity & Core Loop Fix (2-4 weeks)
1. Free photo scanning with weekly limits
2. Anti-waste copy and framing throughout Discover
3. Collapse to 2 subscription tiers
4. Onboarding flow (camera-first)

### Phase 2: Retention & Depth (4-6 weeks)
5. Enhanced recipe placeholders (emoji + gradient cards)
6. Post-cook feedback (rating + would make again)
7. "Use It All" recipe filter
8. Grocery/shopping list (premium)

### Phase 3: Growth & Engagement (6-8 weeks)
9. Personalized recommendations
10. Curated weekly collections (premium)
11. Recipe sharing
12. Waste-reduction stats and achievements

### Phase 4: Polish & Scale
13. Real recipe images (AI-generated for top recipes)
14. Dietary preferences and allergy filtering
15. Improved mood classification
16. Monthly cooking insights

---

## Open Questions for Product Owner

1. **Pricing:** $0.99/month won't cover API costs (OpenAI Vision, Spoonacular). Have you modeled unit economics? What's the target price point?
2. **Recipe dataset quality:** Has the 20k dataset been audited? Are there duplicates, low-quality entries, or offensive content?
3. **Localization:** Is this English-only? The recipe dataset appears English. Are other markets planned?
4. **Analytics:** Is there any analytics/telemetry in place to measure retention, conversion, feature usage? If not, this should be added before making product changes.
5. **App Store presence:** What's the current App Store listing? Screenshots, description, and keywords should align with the "photo → recipes, anti-waste" positioning.
