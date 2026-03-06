# CookSavvy V2 Mock UI — Design Specification

**Mock file:** `claude-skills-ui-mock.swift`
**Preview in Xcode:** Open the file, use Canvas to preview any `#Preview` block.

---

## Overview

This mock proposes a redesign of CookSavvy with a **dark immersive theme**, a **two-state ingredient-first Discover flow** with personal recipe history (recent & saved), a **hands-free Cook Mode**, and a **gamified profile/journey screen**.

### Tab Structure

| Tab | Icon (SF Symbol) | Screen | Purpose |
|-----|-------------------|--------|---------|
| Discover | `compass.drawing` | `V2DiscoverView` | Ingredient selection + recipe discovery + recent/saved recipes |
| Journey | `trophy.fill` | `V2JourneyView` | Profile, stats, achievements |

Native `TabView` with `.tint` set to accent orange.

**Screens accessed via navigation (not tabs):**

| Screen | Presented from | Presentation |
|--------|---------------|--------------|
| Recipe List | Discover ("See All" on Recent/Saved), Journey ("See All" on My Recipes) | NavigationLink (push) |
| Recipe Detail | Discover (recipe tap), Recipe List (recipe tap) | NavigationLink (push) |
| Cook Mode | Recipe Detail ("Start Cooking") | `.fullScreenCover` |
| Create Recipe | Journey ("+ Create" card / "Add Recipe" button), Discover ("+ Add Your Own" card in Saved) | `.sheet` |

---

## Design System

### Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `bg` | `#0F0F17` | App background, all screens |
| `surface` | `#1C1C26` | Input fields, segmented controls, inactive elements |
| `surfaceLight` | `#292936` | Slightly elevated surface (progress dots) |
| `card` | `#21212E` | Card backgrounds (frost cards) |
| `accent` | `#FF8C33` | Primary action color, CTAs, selected states, tab tint |
| `accentSoft` | `accent` at 15% opacity | Soft backgrounds for accent elements |
| `mint` | `#4DD9B8` | Success/positive states, match badges, "fresh" mood |
| `rose` | `#F2597F` | Urgency/warnings, expiration alerts, "bold" mood |
| `lavender` | `#A680F2` | Secondary accent, "comfort" mood, difficulty badge |
| `sky` | `#59A6FF` | Informational, "quick" mood |
| `gold` | `#FFD14D` | Ratings, level badges, achievements |
| `text1` | `#FFFFFF` | Primary text |
| `text2` | `#FFFFFF` at 65% | Secondary text, subtitles |
| `text3` | `#FFFFFF` at 35% | Tertiary text, labels, placeholders |
| `divider` | `#FFFFFF` at 8% | Borders, separators |

### Corner Radii

| Token | Value | Usage |
|-------|-------|-------|
| `r12` | 12pt | Small elements (recipe thumbnails, small badges) |
| `r16` | 16pt | Cards, input fields, list rows, buttons |
| `r20` | 20pt | Standard frost cards, containers |
| `r24` | 24pt | Hero images, featured cards |
| `r32` | 32pt | Sheet-style rounded top (recipe detail content area) |

### Visual Effects

**Frost Card** (`frostCard` modifier):
- Background: `card` color fill
- Border: Diagonal gradient stroke (`white` 12% -> 3% opacity, 0.5pt width)
- Applied to: Recipe rows, stat cards, achievement rows, mini recipe cards, settings cards

**Neon Glow** (`neonGlow` modifier):
- Two-layer shadow: `color` at 60% opacity (tight radius) + `color` at 30% opacity (wider radius, offset down)
- Applied to: Selected mood pills, CTA buttons, profile avatar, unlocked achievements

### Typography

All text uses `system` font with `.rounded` design variant.

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Screen title | 28-34pt | Bold | `text1` |
| Section label | 11pt | Bold + tracking 1.5 | `text3` |
| Card title | 15-22pt | Bold | `text1` |
| Card subtitle/tagline | 13-15pt | Regular | `text2` |
| Meta info (time, cal) | 11-12pt | Medium | `text3` |
| Chip text | 13pt | Semibold | `text1` |
| Button text | 15-17pt | Bold | White |

Section labels use UPPERCASE + letter-spacing (tracking 1.5) pattern throughout.

---

## Screen 1: Discover (Two-State)

**File reference:** `V2DiscoverView`

This screen has two visual states controlled by ingredient selection plus an explicit `showResults` transition:

### State 1 — Ingredient Selection + Personal History (landing)

This is what the user sees when opening the app. It combines ingredient selection with quick access to recently viewed and saved recipes.

**Layout (top to bottom):**

1. **Greeting Header**
   - Dynamic time-of-day text: "Good Morning/Afternoon/Evening/Late Night Cravings?" + matching emoji
   - Large title: "What's in your kitchen?"
   - Subtitle: "Add ingredients and we'll find recipes for you"
   - **Data source:** System clock (`Calendar.current.component(.hour, ...)`)
   - **Integration note:** Static, no service needed.

2. **Search Bar**
   - Magnifying glass icon (left) + text field + clear button (appears when text entered) + camera button (right)
   - Background: `surface` with `divider` border
   - **Behavior:** Filters the ingredient grid below in real-time by name (case-insensitive)
   - **Camera button:** Opens camera for AI ingredient detection (paid tiers only). In free tier, either hide the button or show upgrade prompt on tap.
   - **Data source:** Local filter on `IngredientsService` results
   - **Integration note:** Connect to `IngredientsService` for autocomplete. Camera triggers `IngredientDetectionServiceProtocol` flow (existing).

3. **Recent Recipes**
   - Section label "RECENT" with "See All" link (accent color) on right
   - Horizontal scroll of `V2MiniRecipeCard` components (see Shared Components below)
   - "See All" pushes `V2RecipeListView` (NavigationLink) showing all recent recipes
   - **Behavior:** Tapping a card navigates to Recipe Detail. Shows up to 4-5 cards in the scroll.
   - **Data source:** `UserDataService.getRecentRecipes()` (existing)
   - **Integration note:** Reuses existing recent recipe tracking. No new service needed. This replaces the dedicated Recent Recipes tab from V1.

4. **Saved Recipes**
   - Section label "SAVED" with "See All" link (accent color) on right
   - Same horizontal scroll of `V2MiniRecipeCard` components
   - **"+ Add Your Own" ghost card** at the end of the scroll: same 140pt width as `V2MiniRecipeCard`, dashed `divider`-color border, `+` icon (accent) centered, "Add Your Own" label below. Tapping opens Create Recipe sheet.
   - "See All" pushes `V2RecipeListView` showing all favorited recipes (including user-created ones)
   - **Behavior:** Same as Recent — tap card for detail, "See All" for full list. User-created recipes appear mixed in with a small pencil icon overlay on the thumbnail to distinguish them.
   - **Data source:** `UserDataService.getFavorites()` (existing) + `UserDataService.getUserRecipes()` (new)
   - **Integration note:** Reuses existing favorites tracking. This replaces the dedicated Favorites tab from V1. The bookmark icon on recipe rows/detail toggles favorite status via the same `UserDataService.toggleFavorite()`. User-created recipes are automatically considered "saved."

5. **Category Filter Chips**
   - Horizontal scroll of capsule-shaped chips: Proteins, Veggies, Dairy, Grains, Fruits, Spices
   - Each chip has emoji + name
   - **Behavior:** Single-select toggle. Tap selects (fills with category color), tap again deselects. Filters the ingredient grid to show only that category. Unselected = show all.
   - **Data source:** Hardcoded categories (same as current app ingredient categories)

6. **Ingredient Grid**
   - Section label shows current filter (e.g., "PROTEINS" or "ALL INGREDIENTS")
   - 4-column `LazyVGrid` of ingredient bubbles
   - Each bubble: 60pt circle with emoji + name below
   - **Selected state:** Orange accent border (2pt), soft accent background, slight scale-up (1.08x), bold name in accent color
   - **Unselected state:** `surface` background, `divider` border (1pt), regular weight name in `text2`
   - **Behavior:** Tap toggles selection. After at least one ingredient is selected, the "Find Recipes" CTA becomes available and transitions to State 2 when tapped.
   - **Animation:** `.spring(response: 0.3)` on toggle
   - **Data source:** `IngredientsService.allIngredients()` or similar. In mock, 20 ingredients across 6 categories.
   - **Integration note:** This replaces the current `IngredientsInputView` search-bar + autocomplete + fast-ingredient flow. The grid approach removes the need for typed autocomplete — the user taps directly. The search bar acts as a filter for the grid, not a separate autocomplete dropdown.

### State 2 — Recipe Results (ingredients selected)

Appears after the user taps the "Find Recipes" CTA once at least one ingredient is selected. Animated transition: slide from trailing + opacity.

**Layout (top to bottom):**

1. **Compact Header**
   - Same time-of-day greeting (smaller, 14pt)
   - Title: "Recipes for you" (28pt)
   - Profile avatar (right side): Gradient circle with chef emoji. Tapping could navigate to Journey or show a profile sheet.

2. **Selected Ingredients Strip**
   - Section label "YOUR INGREDIENTS" with "Edit" button on the right
   - Horizontal scroll of removable chips: emoji + name + X button
   - "+" circle button at the end
   - **"Edit" button behavior:** Clears all ingredients and mood, returning to State 1 for full re-selection.
   - **"+" button behavior:** Same as Edit — clears and returns to State 1. (In real implementation, could open a sheet overlay instead of clearing.)
   - **Chip X button:** Removes individual ingredient. If last ingredient removed, transitions back to State 1.
   - **Data source:** Local state (selected ingredients array)
   - **Integration note:** These are the ingredients passed to `RecipeSourceProtocol.searchRecipes(ingredients:)`.

3. **Mood Filter**
   - Section label "REFINE BY MOOD"
   - Horizontal scroll of mood pills: Cozy, Fresh, Bold, Comfort, Quick
   - Each pill has SF Symbol icon + name, each with unique color
   - **Selected state:** Gradient background (L->R), white text, neon glow
   - **Unselected state:** Color at 12% opacity background, color text, subtle border
   - **Behavior:** Single-select toggle. Reranks recipe results instead of hard-filtering them. Optional — can be nil.
   - **Implementation note:** Current app behavior uses lightweight heuristics from existing recipe data:
     - `Quick`: boosts short cook time, easy complexity, "quick/fast/easy" terms
     - `Fresh`: boosts salads, citrus, herbs, greens, avocado, yogurt, lighter ingredient signals
     - `Bold`: boosts spicy/garlic/smoked/curry keywords and stronger cuisine signals
     - `Comfort`: boosts pasta/cheese/potato/rice/creamy/baked keywords
     - `Cozy`: boosts soup/stew/broth/ramen/roast/warm keywords and longer cook times
   - **Rationale:** Reranking preserves the original search relevance while still making the mood visibly affect hero selection and list order.

4. **Best Match — Featured Hero Card**
   - Section label "BEST MATCH"
   - Full-width card (240pt height) with gradient background + emoji
   - Bottom overlay (gradient black -> transparent): match percentage badge + recipe name + cook time / difficulty / star rating
   - **Match badge:** Mint-colored capsule with checkmark.seal icon + "83% match" text
   - **Behavior:** Taps navigate to Recipe Detail (NavigationLink push)
   - **Data source:** First recipe from filtered results, sorted by match score
   - **Integration note:** Match percentage should come from the recipe source. `OfflineRecipeSource` could calculate it as (matched ingredients / total recipe ingredients). `OnlineRecipeSource` and `AIRecipeSource` may return their own relevance scores.

5. **More Recipes List**
   - Section label "MORE RECIPES" with count badge (e.g., "6 found")
   - Vertical list of recipe rows (no grid — single column)
   - Each row: 80x80 gradient image (left) + title + tagline + meta (cook time, calories, star rating) + bookmark icon (right)
   - Row wrapped in frost card
   - **Bookmark icon:** Filled + accent color if saved, outline + `text3` if not
   - **Behavior:** Tap navigates to Recipe Detail. Bookmark icon should be tappable independently (toggle favorite).
   - **Data source:** Remaining recipes from filtered results (skip first which is the hero)

### Transition Between States

- Controlled by a dedicated `showResults` state that is triggered by the "Find Recipes" CTA
- State 1 uses `.transition(.move(edge: .leading).combined(with: .opacity))`
- State 2 uses `.transition(.move(edge: .trailing).combined(with: .opacity))`
- Spring animation: `response: 0.45, dampingFraction: 0.85`

---

## Shared Components

### `V2MiniRecipeCard`

Compact card for horizontal scroll in Recent/Saved sections on the Discover landing page.

- **Width:** 140pt fixed
- **Top:** Gradient recipe image with emoji (100pt height)
- **Bottom:** Recipe name (13pt bold, single line truncated) + clock icon + cook time (11pt)
- **Padding:** 10pt horizontal, 8pt vertical on text area
- **Style:** Frost card with r16 corners, clipped to rounded rect
- **Behavior:** Taps navigate to Recipe Detail via NavigationLink

### `V2RecipeListView`

Full list view pushed via NavigationLink from "See All" buttons.

- **Navigation title:** Dynamic — "Recent Recipes" or "Saved Recipes" (passed as parameter)
- **Title display mode:** `.large`
- **Content:** Vertical list of `V2RecipeRow` cards with 12pt spacing
- **Padding:** 20pt horizontal, 12pt top
- **Background:** `bg` color
- **Behavior:** Each row taps to Recipe Detail

---

## Screen 2: Recipe Detail

**File reference:** `V2RecipeDetailView`

Pushed via NavigationLink from Discover. Hides the navigation bar and provides its own back button.

**Layout (top to bottom):**

1. **Hero Image (340pt)**
   - Full-bleed gradient + emoji, ignores top safe area
   - Floating buttons over the image (top, padded 56pt from top for status bar clearance):
     - **Back button** (left): Chevron left in `.ultraThinMaterial` circle (40pt). Pops navigation.
     - **Bookmark button** (right): Bookmark icon in `.ultraThinMaterial` circle. Toggles saved state. Filled + accent color when saved.
   - **Integration note:** In the real app, replace gradient+emoji with `AsyncImageDisk` loading the recipe's actual image URL. The gradient serves as a placeholder/fallback.

2. **Content Card** (overlaps hero by 32pt with rounded top corners, r32)
   - Background: `bg` color
   - **Title block:**
     - Recipe name (28pt bold)
     - Tagline (15pt, `text2`)
     - Star rating + numeric rating + "by Author" attribution
   - **Integration note:** `tagline` is a new field not in the current `Recipe` model. Could be derived from the recipe description's first sentence, or added as an optional field. `author` / `rating` are also new — omit or derive from source if not available.

3. **Stats Row**
   - 4 equal-width stat pills in a horizontal row, inside a single frost card:
     - Time (clock icon, accent) — e.g., "25m"
     - Servings (person.2 icon, mint) — e.g., "2"
     - Calories (flame icon, rose) — e.g., "480"
     - Difficulty (chart.bar icon, lavender) — e.g., "Medium"
   - **Data source:** `Recipe.cookTime`, `Recipe.servings`, `Recipe.calories`, `Recipe.complexity`

4. **Ingredients Section**
   - Section label "INGREDIENTS"
   - Vertical list inside a frost card: each ingredient is a row with an accent dot (8pt circle) + ingredient name, separated by dividers
   - **Data source:** `Recipe.ingredients` (existing)

5. **Steps Section**
   - Section label "STEPS"
   - Each step is its own frost card with: numbered circle (gradient background matching recipe) + step text + optional timer badge
   - **Timer badge:** If the step has an associated timer, show an accent capsule with timer icon + "X min". In the real implementation, tapping this badge could pre-set the Cook Mode timer.
   - **Data source:** `Recipe.instructions` (existing, may need parsing into individual steps if stored as a single string)
   - **Integration note:** The `timerMinutes` per step is a new concept. Options:
     - AI-powered: Parse times from instruction text (e.g., "simmer for 10 minutes" -> 10)
     - Manual: Add optional timer field per step in the data model
     - Heuristic: Simple regex on step text

6. **Sticky "Start Cooking" Button**
   - Pinned to bottom of screen, above safe area
   - Full-width gradient button (recipe's gradient colors) with play icon + "Start Cooking" text
   - Neon glow effect using recipe's primary gradient color
   - Fades in from bottom with gradient overlay so it doesn't hard-clip the scroll content
   - **Behavior:** Opens Cook Mode as `.fullScreenCover`
   - **Integration note:** Cook Mode is a new screen not in the current app. See below.

---

## Screen 3: Cook Mode (Hands-Free)

**File reference:** `V2CookModeView`

Full-screen modal (`.fullScreenCover`) designed for use while cooking. Prioritizes large text and simple gestures.

**Layout:**

1. **Top Bar**
   - **Close button** (left): X icon in `surface` circle. Dismisses the full-screen cover.
   - **Center:** Recipe name (15pt bold) + "Step X of Y" subtitle
   - **Progress ring** (right): Circular progress indicator showing completed steps count. Animated.

2. **Step Progress Dots**
   - Horizontal row of capsules, one per step
   - Current step: accent color, expanded width (fills available space)
   - Completed steps: mint color, 16pt fixed width
   - Remaining steps: `surfaceLight` color, 16pt fixed width
   - Animated on step change

3. **Step Content (center of screen)**
   - **Step text:** Large (28pt bold), centered, multiline
   - Transitions with slide animation (swipe-like) between steps
   - **Timer (conditional):** Only shown for steps that have `timerMinutes`. Displays:
     - Circular timer ring (120pt diameter): `surface` track + accent fill
     - Digital time display (32pt monospaced) inside the ring
     - "Start Timer" / "Pause" capsule button below
   - **Integration note:** The timer in the mock is visual only (no actual countdown). Real implementation needs:
     - `Timer.publish` or `TimelineView` for countdown
     - Background timer support (local notification when timer completes)
     - Audio/haptic alert on completion
     - Keep screen awake (`.persistentSystemOverlays(.hidden)` or `UIApplication.shared.isIdleTimerDisabled`)

4. **Bottom Navigation**
   - Three buttons in a row:
     - **Previous** (left): Chevron left in `surface` circle (56pt). Disabled on first step.
     - **Done** (center): Full-width capsule with gradient background + neon glow. Shows checkmark + "Done" (or "Finish" on last step). Marks current step complete and advances to next.
     - **Next** (right): Chevron right in `surface` circle (56pt). Disabled on last step.
   - **Behavior:**
     - "Done" adds current step to `completedSteps` set and auto-advances
     - Previous/Next allow free navigation without marking complete
     - Timer resets when switching steps
   - **Integration note:** Consider adding voice commands ("Hey Siri, next step") and swipe gestures as alternatives to button taps for truly hands-free operation.

---

## Screen 4: Journey (Profile + Stats + Achievements)

**File reference:** `V2JourneyView`

This is an entirely **new feature**. Gamifies the cooking experience.

**Layout (top to bottom):**

1. **Profile Header** (centered)
   - Avatar: 80pt gradient circle (accent -> rose) with chef emoji. Neon glow.
   - Name: "Home Chef" (24pt bold) — this could be the user's name or a title
   - Join date subtitle
   - **Level badge:** Gold capsule showing level + rank name (e.g., "Level 7 - Sous Chef")
   - **Integration note:** Requires user profile storage. Could be minimal (just a display name stored in UserDefaults) or full (account system). Level/rank can be derived from total recipes cooked.

2. **Stats Grid**
   - 3 equal-width frost cards in a row:
     - Recipes Cooked (fork.knife icon, accent color)
     - Day Streak (flame icon, rose color)
     - Hours Cooking (clock icon, mint color)
   - Each card: icon (20pt) + large value (26pt bold) + two-line label (11pt)
   - **Data source:** Derived from `UserDataService` (recipe history with timestamps). Streak requires date tracking of cooking sessions.
   - **Integration note:** New fields needed in user data:
     - Track "cooked" state per recipe (currently only "viewed" and "favorited")
     - Track cooking session timestamps for streak calculation
     - Estimate cooking time from recipe cookTime for total hours

3. **My Recipes**
   - Section label "MY RECIPES" with count badge (e.g., "3 recipes") + "See All" link on right
   - **"+ Create" card** as the first item: 140pt width `V2MiniRecipeCard`-sized frost card with gradient accent background (subtle), large `+` icon (white, 28pt) centered, "Add Recipe" label below (13pt bold). Neon glow on the `+` icon.
   - Followed by horizontal scroll of `V2MiniRecipeCard` components showing user-created recipes
   - User-created recipe cards have a small pencil icon badge in the top-right corner of the thumbnail
   - "See All" pushes `V2RecipeListView` showing all user-created recipes
   - **Behavior:** "+" card opens Create Recipe sheet. Recipe cards navigate to Recipe Detail (same as any recipe). Users can edit their own recipes from the detail view (edit button replaces bookmark for user-owned recipes).
   - **Data source:** `UserDataService.getUserRecipes()` (new)
   - **Integration note:** Requires new `getUserRecipes()` method on `UserDataService`. User recipes are stored in the same `Recipe` table with an `isUserCreated` flag (or a `source` field). They participate in search results, favorites, and recent recipes like any other recipe.

5. **Weekly Activity Calendar**
   - Section label "THIS WEEK"
   - 7 columns (M-S), each with a circle + day letter
   - Active days: accent-filled circle with white checkmark
   - Inactive days: `surface`-filled circle
   - Today: accent border ring around circle
   - All wrapped in a frost card
   - **Data source:** Cooking session dates from current week
   - **Integration note:** Requires `UserDataService` to track cooking session dates.

6. **Achievements**
   - Section label "ACHIEVEMENTS" with "X/Y" counter
   - Vertical list of achievement rows (frost cards)
   - Each row: icon circle (colored if unlocked, surface if locked) + title + description + progress bar + percentage
   - Progress bar: `surface` track with colored fill proportional to progress
   - Icon gets neon glow when unlocked
   - **Integration note:** Define achievements as a static list. Progress calculated from user data:
     - "First Flame" — cooked 1 recipe (binary)
     - "Week Warrior" — 7-day streak (progress = current streak / 7)
     - "Globe Trotter" — 5 cuisines (progress = unique cuisines / 5)
     - "Speed Demon" — 10 quick recipes (progress = quick recipes cooked / 10)
     - "Master Chef" — 50 recipes (progress = total / 50)
     - "Recipe Creator" — create your first recipe (binary)
     - "Cookbook Author" — create 10 recipes (progress = user recipes / 10)

7. **Recent Activity**
   - Section label "RECENT ACTIVITY"
   - Vertical list inside a frost card with dividers
   - Each row: 50x50 recipe thumbnail + name + "Cooked X days ago" + star rating
   - **Data source:** Recent entries from `UserDataService.recentRecipes()`, extended to track cook dates (not just view dates)

### New Data Requirements

This screen needs extensions to `UserDataService`:
- `markAsCooked(recipeId:, date:)` — new concept (vs. current "viewed")
- `cookingSessions() -> [Date]` — for streak and calendar
- `currentStreak() -> Int`
- `totalCookingTime() -> TimeInterval`
- `uniqueCuisines() -> Int`
- `quickRecipesCooked() -> Int`
- `getUserRecipes() -> [Recipe]` — fetch user-created recipes
- `saveUserRecipe(recipe:)` — persist a new user-created recipe
- `updateUserRecipe(recipe:)` — edit an existing user-created recipe
- `deleteUserRecipe(recipeId:)` — remove a user-created recipe

---

## Screen 5: Create Recipe (Sheet)

**File reference:** `V2CreateRecipeView`

Presented as a `.sheet` from Journey's "My Recipes" section or Discover's Saved "+" card. Multi-step form with progress indicator.

**Presentation:** `.sheet` with `.presentationDetents([.large])`. Sheet includes a drag indicator and a close (X) button.

**Layout:**

1. **Header (persistent across all steps)**
   - Close button (X) top-left
   - Step title centered (changes per step: "Name Your Recipe", "Add Ingredients", etc.)
   - Step indicator: row of small dots (same pattern as Cook Mode progress dots). Current step = accent, completed = mint, remaining = surfaceLight.

2. **Step 1 — Name & Photo**
   - Recipe name text field (large, 22pt, placeholder: "Recipe name")
   - Emoji picker grid: 4x3 grid of food emojis for the recipe thumbnail (mock replaces real photo upload)
   - Tagline text field (15pt, placeholder: "Short description — e.g. 'Creamy comfort in a bowl'")
   - Selected emoji displayed in a large gradient preview card (same as `V2RecipeImage`, 160pt height)

3. **Step 2 — Ingredients**
   - Ingredient list: vertical stack of text fields, each with a delete (minus circle) button on the left
   - "+" button at the bottom to add a new empty ingredient row
   - **Integration note:** In the real app, this could reuse the ingredient grid/autocomplete from Discover for selection, plus free-text input for quantities (e.g., "2 cups flour").

4. **Step 3 — Steps**
   - Step list: vertical stack of numbered text fields (multiline), each with delete button and drag handle for reordering
   - Each step has an optional timer toggle: tap to add a timer, enter minutes
   - "+" button at bottom to add a new step
   - **Integration note:** Drag-to-reorder via `onMove` in a `List` or manual implementation.

5. **Step 4 — Details**
   - Cook time picker: horizontal scroll of preset capsules (5m, 10m, 15m, 20m, 30m, 45m, 60m, 90m) or custom input
   - Servings stepper: minus/plus buttons around a number (1–12)
   - Difficulty selector: 3 capsules (Easy, Medium, Hard) — single select, each with its own color
   - Cuisine/mood tag (optional): horizontal scroll of mood pills (reuses `MoodPill` component)

6. **Step 5 — Review & Save**
   - Full preview of the recipe in a compact card layout: emoji image + name + tagline + stats row + ingredient count + step count
   - "Save Recipe" CTA button: full-width, accent gradient, neon glow (same style as "Start Cooking")
   - **Behavior:** Saving dismisses the sheet. The new recipe appears in Journey's "My Recipes" and Discover's "Saved" section immediately.

**Navigation between steps:**
- "Next" button pinned to bottom (accent gradient capsule, full-width)
- "Back" text button top-left (replaces close button after step 1)
- Swipe-back gesture supported
- Spring animation on step transitions (same as Cook Mode)

**Empty / First-time state:**
- If the user has no recipes yet, Journey's "My Recipes" section shows only the "+" card with a subtitle: "Share your own creations"

---

## Integration Mapping (Mock -> Real App)

| Mock Concept | Current App Equivalent | Integration Strategy |
|---|---|---|
| Ingredient selection grid | `IngredientsInputView` + `IngredientsInputSearchBar` + `IngredientsInputAutocompletion` + `IngredientsInputFastIngredientSelector` | Replace existing views. Grid replaces autocomplete+fast-ingredients. Search bar becomes grid filter. |
| Category filter chips | None (new) | Static list derived from ingredient categories in DB |
| Mood filter | None (new) | New optional parameter. Implement as cook-time/tag heuristics for MVP. |
| Recent recipes section | `RecentRecipesView` (separate tab) | Move from dedicated tab to horizontal scroll on Discover landing. Same `UserDataService.getRecentRecipes()` data source. |
| Saved recipes section | `FavoritesView` (separate tab) | Move from dedicated tab to horizontal scroll on Discover landing. Same `UserDataService.getFavorites()` data source. |
| Recipe list (See All) | `SearchResultsView` (partial) | New `V2RecipeListView`. Reuses `V2RecipeRow` component. Pushed within Discover navigation stack. |
| Recipe results list | `SearchResultsView` | Replace with new layout. Same data flow through coordinator. |
| Recipe detail | `RecipeDetailsView` | Replace with new layout. Same ViewModel pattern. |
| Cook Mode | None (new) | New screen + ViewModel + Coordinator. Extend `IngredientsCoordinator`. |
| Journey / Profile | None (new) | New feature. Needs extended `UserDataService`, `JourneyCoordinator`, `JourneyView`, `JourneyViewModel`. |
| Star ratings | None (new) | New field on `Recipe` or user-generated post-cook. |
| Bookmark (save) | Favorites (heart) | Rename/restyle. Same `UserDataService.toggleFavorite()` underneath. |
| Neon glow effect | None | Add as view modifier in `Theme/` |
| Frost card effect | None (app uses shadows) | Add as view modifier in `Theme/` |
| Dark color palette | `DefaultTheme` (light) | New theme conforming to `AppTheme`. Inject at root. Could be user-selectable. |
| My Recipes section (Journey) | None (new) | New section in Journey. `UserDataService.getUserRecipes()`. Recipes stored with `isUserCreated` flag in DB. |
| Create Recipe sheet | None (new) | New `V2CreateRecipeView` + `CreateRecipeViewModel`. Sheet presented from Journey and Discover. Writes to DB via `UserDataService.saveUserRecipe()`. |
| "+" card in Saved | None (new) | Ghost card at end of Saved scroll. Opens Create Recipe sheet. |

---

## Architecture Notes for Implementation

Following the existing MVVM + Coordinator pattern:

### Coordinator Changes
- `AppCoordinator`: Update from 4 tabs to 2 tabs (Discover, Journey)
- Remove `FavoritesCoordinator` and `RecentRecipesCoordinator` (absorbed into Discover)
- Extend `IngredientsCoordinator` to handle Cook Mode `.fullScreenCover` presentation and `V2RecipeListView` navigation
- New `JourneyCoordinator` for Journey tab (or extend `SettingsCoordinator` if Settings moves to Journey); handles Create Recipe `.sheet` presentation
- Settings: Move to Journey screen (gear icon in nav bar) or keep as separate access point

### New ViewModels Needed
- `DiscoverViewModel` — holds selected ingredients, selected mood, search text, category filter, recipe results, recent recipes, saved recipes
- `CookModeViewModel` — holds current step, timer state, completed steps
- `JourneyViewModel` — holds profile data, stats, achievements, activity history, user recipes
- `RecipeListViewModel` — holds recipe list for "See All" (Recent, Saved, or My Recipes)
- `CreateRecipeViewModel` — holds multi-step form state (current step, recipe fields, validation)

### Service Changes
- Extended `UserDataService` with cooking session tracking (for Journey stats)
- Extended `UserDataService` with user recipe CRUD: `getUserRecipes()`, `saveUserRecipe()`, `updateUserRecipe()`, `deleteUserRecipe()`
- `Recipe` model extended with `isUserCreated: Bool` field (or `source: RecipeSource` enum)
- No new services needed for Recent/Saved on Discover (reuses existing `UserDataService`)

### Theme Changes
- New struct conforming to `AppTheme` with the dark palette
- New view modifiers: `frostCard`, `neonGlow`
- Register in `AppTheme.swift` + `@Environment(\.appTheme)`

### Tab Structure Change
- `AppCoordinator` needs updating: 4 tabs -> 2 tabs (Discover, Journey)
- Remove separate Favorites and Recent tabs (absorbed into Discover's landing page)
- Settings moves to Journey screen (gear icon in nav bar)
