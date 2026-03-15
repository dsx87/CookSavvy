# CookSavvy Product Audit (GPT)

Date: 2026-03-13
Scope: Product strategy audit based on the current repository, screens, view models, services, monetization setup, and shipped product language.
Purpose: Give future models a reusable, detailed product brief they can build on without re-reading the full codebase.

## 1. Short Conclusion

CookSavvy does not appear visually broken. The larger issue is product direction.

The product currently behaves like a combination of three different products:

1. An ingredient-to-recipe utility for fast dinner decisions.
2. An AI demo with camera detection and planned AI recipes.
3. A habit and identity product with streaks, levels, achievements, and a "Journey" area.

Those three directions are not fully compatible at this stage. The app needs a sharper product thesis before it adds more features.

My recommendation is to define CookSavvy as:

`The fastest way to turn 3-6 ingredients into one confident dinner choice.`

That direction is stronger than the current mix because it is:

- Clear
- Useful
- Easy to explain
- Easier to monetize
- Easier to evaluate with product metrics

## 2. What The Product Currently Appears To Be

### Stated promise

The main project docs describe the app as:

- "A hobby iOS recipe app that suggests recipes based on user-provided ingredients."
- Free tier = local recipe database
- Paid tiers = online recipes and AI features

Relevant repo references:

- `CLAUDE.md`
- `AGENTS.md`

### Current product shape in the repo

The shipped experience currently includes:

- `Discover` as the main ingredient and recipe flow
- `Journey` as a second major destination
- `Recipe Details`
- `Cook Mode`
- `Create Recipe`
- `Camera`
- `Settings`
- `Upgrade`

This is a fairly broad scope for a product that has not yet locked its core value loop.

## 3. Core Product Diagnosis

### Main diagnosis

The app is over-developed in breadth relative to its product conviction.

The repo shows strong engineering structure and decent UI structure, but product choices are still centered on implementation categories instead of user outcomes.

The most visible example is that users are asked to think about:

- Local recipes
- Online recipes
- AI recipes

That is a backend/service distinction, not a user mental model.

### What is strong already

- The ingredient-first entry point is directionally good.
- Discover is the best candidate for the core product loop.
- The app already has a cook flow, save flow, and some persistence.
- There is enough local data to create a usable offline experience.
- The codebase already contains infrastructure for personalization, usage tracking, and AI support.

### What is not decided enough

- Who the primary user is
- What job the product is solving first
- Whether AI is the product or just a supporting capability
- What the premium value proposition actually is
- What should drive retention after the first successful use

## 4. Likely Product Misdirections And Better Alternatives

This section lists the most likely wrong or weak product decisions in the current direction, why they are risky, and what to do instead.

### 4.1 Source-first product packaging is probably wrong

Current behavior:

- Settings exposes `Local Recipes`, `Online Recipes`, and `AI Recipes`.
- Recipe cards/details expose source badges such as local, web, AI, user-created.
- Subscription plans are described in terms of source type.

Why this is a problem:

- Users do not wake up wanting "API recipes."
- Users want a good dinner idea, a quick match, fewer leftovers, or less effort.
- Source choice adds cognitive load and weakens trust because it makes the product feel stitched together.
- It exposes implementation rather than value.

Better decision:

- Hide recipe-source selection from most users.
- Use one recommendation engine that chooses the best available result.
- Surface source only when trust/explanation matters, and even then in plain language.
- Repackage premium around outcomes like:
  - faster capture
  - better matching
  - pantry memory
  - substitutions
  - personalized results

Evidence:

- `CookSavvy/Views/Settings/SettingsView.swift:95`
- `CookSavvy/Views/Settings/SettingsViewModel.swift:79`
- `CookSavvy/Views/Discover/DiscoverView.swift:367`
- `CookSavvy/Theme/Strings.swift:148`

### 4.2 The app is trying to be too many products too early

Current behavior:

- Discover tries to solve the main utility job.
- Journey adds profile identity, level, stats, weekly activity, achievements, and recent sessions.
- The product also includes custom recipe creation.

Why this is a problem:

- Utility products need a sharp first promise before building identity systems.
- Achievements and levels only work if the user already gets strong recurring value.
- "Journey" implies long-term behavior change, but the core recommendation engine is not yet strong enough to justify that layer.

Better decision:

- Keep Discover as the center of the product.
- Reframe the second tab around practical utility, not identity.
- A stronger second tab would be something like:
  - Saved
  - Pantry
  - Cooked
  - This Week

What to de-emphasize for now:

- Level system
- Achievement-heavy framing
- Generic gamification

Evidence:

- `CookSavvy/Views/Journey/JourneyView.swift:7`
- `CookSavvy/Theme/Strings.swift:105`

### 4.3 Premium is packaged around implementation, not willingness to pay

Current behavior:

- Free = local recipes
- API = online recipes + camera detection
- AI = AI recipes + AI detection

Why this is a problem:

- "API" is not a customer-facing value proposition.
- The free/paid split appears to be designed from architecture layers rather than customer value.
- Users will pay for speed, confidence, convenience, and personalization, not for "online recipes" as a technical concept.

Better decision:

- Collapse to one premium tier first.
- Sell premium as:
  - camera scan
  - better ranking
  - pantry memory
  - smart substitutions
  - more personalized recommendations

Only add a second tier later if real usage data proves a meaningful premium segment.

Evidence:

- `CookSavvy/Models/SubscriptionPlan.swift:8`
- `CookSavvy/Views/Upgrade/UpgradeViewModel.swift:92`

### 4.4 AI is being monetized before the product actually delivers it

Current behavior:

- Upgrade screen sells AI-generated recipes.
- The `AIRecipeSource` currently always throws source unavailable.
- There is a real `AIService.generateRecipes` path in the repo, but it is not connected to the product source flow.

Why this is a problem:

- It creates a credibility gap.
- It weakens trust in the premium proposition.
- It makes the roadmap feel aspirational instead of dependable.

Better decision:

Option A:

- Remove AI recipe generation from packaging until it is functional and reliable.

Option B:

- Wire AI generation properly, but only for a narrow, useful job such as:
  - "make something with exactly these leftovers"
  - "give me 3 low-effort options"
  - "substitute missing ingredients"

Preferred choice right now:

- Keep AI as a supporting capability, not the main product label.

Evidence:

- `CookSavvy/Services/Recipe/AIRecipeSource.swift:10`
- `CookSavvy/Services/AI/AIService.swift:62`
- `CookSavvy/Views/Upgrade/UpgradeViewModel.swift:102`

### 4.5 The main wow moment is paywalled too early

Current behavior:

- Camera-based ingredient detection appears to be gated behind paid tiers.

Why this is a problem:

- The camera scan is likely one of the clearest immediate moments of delight.
- If users do not get a fast "wow" moment, conversion becomes harder.
- The product risks looking ordinary before it demonstrates its best capability.

Better decision:

- Allow 1 free scan for all users.
- Or allow a limited number of free scans per month.
- Use the first scan as the activation event that demonstrates value before the paywall.

Evidence:

- `CookSavvy/Views/Discover/DiscoverViewModel.swift:211`
- `CookSavvy/Models/SubscriptionPlan.swift:50`

### 4.6 The recommendation engine is not yet trustworthy enough for the product promise

Current behavior:

- Discover presents a "Best Match".
- Offline recipe retrieval is ordered by database ID.
- Match percentage is calculated after retrieval.
- Mood filters are mostly keyword heuristics.

Why this is a problem:

- The app is making a recommendation claim without a recommendation-quality foundation.
- A user will quickly lose trust if the "best match" feels arbitrary.
- Mood-based ranking is a nice garnish, but not the main decision variable.

Better decision:

Prioritize ranking quality over extra surface features.

Ranking should primarily consider:

- ingredient coverage
- number of missing ingredients
- cook time
- difficulty
- servings fit
- pantry assumptions
- past saves/cooks
- dietary constraints

The product should explain why something was selected:

- "Uses 4 of your 5 ingredients"
- "Only needs 2 pantry items"
- "Ready in 20 min"

Evidence:

- `CookSavvy/Services/Database/DBInterface.swift:290`
- `CookSavvy/Services/Recipe/OfflineRecipeSource.swift:28`
- `CookSavvy/Services/Recipe/RecipeMoodRanker.swift:43`
- `CookSavvy/Views/Discover/DiscoverView.swift:356`

### 4.7 The product has tracking infrastructure, but the main loop is not learning enough

Current behavior:

- There are APIs for recent ingredients, popular ingredients, recent searches, favorites, and cooking sessions.
- Discover currently uses a hard-coded list for popular ingredients.
- The main search flow does not appear to record search or ingredient-usage behavior at the key action point.

Why this is a problem:

- The app cannot become smarter without a real feedback loop.
- Personalization remains mostly theoretical.
- Repeated use will not feel meaningfully better over time.

Better decision:

Turn the core flow into a real learning loop:

- record ingredients used
- record search submissions
- record recipe opens
- record saves
- record completed cooks
- use these signals for:
  - shortcuts
  - recents
  - better ranking
  - repeat recommendations

Evidence:

- `CookSavvy/Services/UserData/UserDataService.swift:43`
- `CookSavvy/Services/UserData/UserDataService.swift:156`
- `CookSavvy/Views/Discover/DiscoverViewModel.swift:183`
- `CookSavvy/Views/Discover/DiscoverViewModel.swift:241`

### 4.8 The free product is broad, but not sharply curated

Current behavior:

- The app imports a very large bundled recipe dataset.
- The dataset zip contains a CSV with approximately 58,783 lines.

Why this is a problem:

- A large corpus gives coverage, but not necessarily good dinner decisions.
- If the core promise is "what can I make tonight?", high-confidence curation matters more than raw breadth.
- Broad datasets can produce noisy, odd, or impractical results.

Better decision:

- Create a curated "high-confidence weeknight set" for primary ranking.
- Use the long-tail corpus as fallback, not as the default heart of the product.
- Define explicit content standards for:
  - ingredient completeness
  - realistic cook time
  - understandable instructions
  - pantry assumption clarity

Evidence:

- `CookSavvy/DataImport/DataImportService.swift:30`
- `CookSavvy/Support/Assets/food-ingredients-and-recipe-dataset-with-images.zip`

### 4.9 Custom recipe creation is probably secondary, not core

Current behavior:

- The app includes a 5-step custom recipe creation flow.
- Journey and Discover both surface creation.

Why this is a problem:

- User-created recipes are usually retention or power-user functionality.
- They are not the strongest first reason to adopt this app.
- It adds scope and navigation weight before the recommendation product is fully proven.

Better decision:

- Keep creation available, but de-prioritize it in product narrative and roadmap.
- Do not let it compete with the main "find dinner from ingredients" loop.

Evidence:

- `CookSavvy/Views/CreateRecipe/CreateRecipeView.swift:1`
- `CookSavvy/Views/Journey/JourneyView.swift:108`

## 5. Product Decisions The App Needs To Make Now

These are not implementation details. These are product choices that should be made explicitly.

### 5.1 Primary job to be done

Choose one:

- Weeknight rescue
- Waste reduction
- Meal planning
- Recipe exploration
- Cooking education

Recommended choice:

- `Weeknight rescue from ingredients already at home`

### 5.2 Primary user segment

Choose one primary segment before optimizing for multiple:

- Busy non-expert home cooks
- Students
- Families
- Diet-focused planners
- Food hobbyists

Recommended choice:

- `Busy non-expert home cooks`

### 5.3 Recommendation contract

Decide what a recommendation means:

- strict match only from listed ingredients
- pantry-plus recommendations
- broad inspiration from similar ingredients

Recommended choice:

- `Pantry-plus with explicit disclosure`

The UI should clearly say:

- "Uses 4 of your 5 ingredients"
- "Also needs oil, salt, and onion"

### 5.4 What premium actually buys

This must be outcome-based, not system-based.

Recommended premium positioning:

- Scan ingredients with camera
- Get better recipe ranking
- Save pantry and preferences
- Get substitutions and rescue ideas
- Keep a smarter cooking history

### 5.5 The role of AI

Decide whether AI is:

- the main product
- a feature
- an invisible infrastructure layer

Recommended choice:

- `AI as a supporting layer, not the core product identity`

Best AI jobs for this product:

- ingredient detection from camera
- missing ingredient substitutions
- leftover rescue
- making a rigid recipe more flexible

### 5.6 The retention loop

Decide what should bring the user back.

Better retention candidates than generic achievements:

- saved pantry
- recent successful dinners
- one-tap reruns
- this week's shortlist
- personalized recommendations from past use

### 5.7 Content strategy

Decide whether the product wins on:

- biggest recipe library
- best practical matches
- best weeknight curation

Recommended choice:

- `Best practical matches`

### 5.8 Metrics

Define success metrics before adding more features.

Recommended core metrics:

- ingredient entry -> recipe results conversion
- recipe results -> recipe details open rate
- recipe details -> start cooking rate
- start cooking -> finish cooking rate
- save rate
- 7-day repeat use
- free scan -> premium conversion

## 6. Recommended Product Direction

### Positioning

CookSavvy should be positioned as:

`A fast dinner decision tool for people who already have ingredients but do not know what to cook.`

### One-sentence pitch

`Tell CookSavvy what you have, and it will quickly show the best realistic dinner options.`

### Core promise

The app should optimize for:

- speed
- confidence
- clarity
- low cognitive effort

### Product principles

1. Do not expose architecture when value wording is available.
2. Recommendation quality matters more than feature count.
3. One successful dinner is more valuable than one clever AI demo.
4. The second use should feel smarter than the first.
5. Trust beats novelty.

## 7. What I Would Keep, Reduce, Remove, And Add

### Keep

- Ingredient-first Discover entry
- Recipe details
- Cook mode
- Save/favorite behavior
- Camera detection as a high-potential capability
- Local/offline support

### Reduce

- Source visibility
- Overuse of mood heuristics as a core ranking layer
- Weight of Journey identity mechanics
- Early prominence of recipe creation

### Remove or hide for now

- AI recipe tier positioning until the source is truly working
- Settings-level source management for most users
- Gamification as a core product story

### Add next

- Better recipe ranking
- "Why this recipe?" explanations
- Missing ingredients list
- Pantry memory
- lightweight preferences:
  - diet
  - allergies
  - max cook time
  - skill level
  - available equipment

## 8. Draft Product Decisions I Would Make Now

If the team needs actual direction, not just critique, these are the decisions I would make.

### Decision 1

Primary product = `ingredient-to-dinner decision tool`

### Decision 2

Primary audience = `busy non-expert home cooks`

### Decision 3

Default recommendation mode = `pantry-plus with transparency`

### Decision 4

Premium = `one paid plan first`

Premium includes:

- camera scan
- pantry memory
- better ranking
- substitutions
- personalized recommendations

### Decision 5

AI is a support layer, not a product family

### Decision 6

The second tab should eventually become a practical utility tab, not a profile identity tab

Suggested replacement direction for Journey:

- Saved
- Pantry
- Cooked
- This Week

### Decision 7

Do not market AI-generated recipes until the product path is implemented and trustworthy

## 9. Suggested 90-Day Product Roadmap

This is a product roadmap, not an engineering estimate.

### Days 0-30: Clarify and simplify

- Reposition the product around the dinner-decision use case
- Remove source language from the user-facing core flow
- Define one premium plan instead of the current architecture-led tiering
- Allow at least one free camera scan
- Add explicit recipe reasoning:
  - ingredient match
  - missing items
  - time
  - difficulty

### Days 31-60: Improve trust and usefulness

- Improve ranking quality
- Add missing-ingredient transparency
- Add max-time and difficulty filters
- Start using real behavior signals for shortcuts and ranking
- Reduce Journey's gamification emphasis

### Days 61-90: Build retention on real value

- Add pantry memory
- Add simple preference capture after first success
- Build "Cook again" and "Use what's left" flows
- Rework second tab toward utility
- Re-test premium conversion after camera and personalization improvements

## 10. Evidence Index For Future Models

These are the main repo references that informed this audit.

### Product framing and scope

- `CLAUDE.md`
- `AGENTS.md`
- `CookSavvy/Theme/Strings.swift:20`
- `CookSavvy/Theme/Strings.swift:81`
- `CookSavvy/Theme/Strings.swift:105`

### Discover as the likely core value loop

- `CookSavvy/Views/Discover/DiscoverView.swift:1`
- `CookSavvy/Views/Discover/DiscoverViewModel.swift:1`
- `CookSavvy/Views/RecipeDetails/RecipeDetailsView.swift:1`
- `CookSavvy/Views/CookMode/CookModeViewModel.swift:1`

### Source-led packaging and settings exposure

- `CookSavvy/Views/Settings/SettingsView.swift:95`
- `CookSavvy/Views/Settings/SettingsViewModel.swift:79`
- `CookSavvy/Models/SubscriptionPlan.swift:8`
- `CookSavvy/Views/Upgrade/UpgradeViewModel.swift:92`

### AI gap

- `CookSavvy/Services/Recipe/AIRecipeSource.swift:10`
- `CookSavvy/Services/AI/AIService.swift:62`

### Recommendation quality gap

- `CookSavvy/Services/Database/DBInterface.swift:290`
- `CookSavvy/Services/Recipe/OfflineRecipeSource.swift:28`
- `CookSavvy/Services/Recipe/RecipeMoodRanker.swift:43`

### Retention and learning loop scaffolding

- `CookSavvy/Services/UserData/UserDataService.swift:30`
- `CookSavvy/Services/UserData/UserDataService.swift:156`
- `CookSavvy/Services/UserData/UserDataService.swift:164`

### Journey scope and gamification

- `CookSavvy/Views/Journey/JourneyView.swift:7`

### Custom recipe creation scope

- `CookSavvy/Views/CreateRecipe/CreateRecipeView.swift:1`

### Dataset breadth

- `CookSavvy/DataImport/DataImportService.swift:30`
- `CookSavvy/Support/Assets/food-ingredients-and-recipe-dataset-with-images.zip`

## 11. Open Questions For Future Work

These are important unanswered questions that future models or human stakeholders should resolve.

1. Are there real users already, or is this still pre-launch?
2. Is the goal a consumer app business, a portfolio project, or a learning project?
3. Which user segment is the actual target?
4. Is the team willing to remove or de-emphasize Journey/achievements if they are not essential?
5. Is there appetite for collapsing to one premium plan?
6. Is the product allowed to recommend pantry staples and missing ingredients, or must it stay strict?
7. How important is offline-first behavior strategically?
8. Is recipe creation expected to be a core retention feature or just a nice extra?

## 12. Suggested Next Prompts For Other Models

These can be copied into future sessions.

### Prompt 1: Positioning

`Using PRODUCT_AUDIT_GPT.md as the source of truth, write 5 positioning options for CookSavvy, then choose the strongest one and justify it.`

### Prompt 2: Roadmap

`Using PRODUCT_AUDIT_GPT.md, create a concrete 12-week product roadmap with goals, hypotheses, user stories, and success metrics.`

### Prompt 3: Scope reduction

`Read PRODUCT_AUDIT_GPT.md and propose which existing screens and features should be kept, hidden, simplified, or removed for a sharper MVP.`

### Prompt 4: Monetization redesign

`Based on PRODUCT_AUDIT_GPT.md, redesign CookSavvy's premium model and paywall copy around user value instead of architecture.`

### Prompt 5: Discover redesign

`Using PRODUCT_AUDIT_GPT.md, redesign the Discover experience to maximize fast dinner decisions, recommendation trust, and conversion to cook mode.`

### Prompt 6: Product analytics

`Read PRODUCT_AUDIT_GPT.md and propose an event taxonomy, activation metric, retention metric, and experiment plan for CookSavvy.`

## 13. Final Recommendation

The strongest next move is not to add more features.

The strongest next move is to choose the product:

- one job
- one primary user
- one recommendation contract
- one premium story

If forced to choose immediately, I would choose:

- Job: `Help me cook dinner from ingredients I already have`
- User: `Busy non-expert home cook`
- Premium: `Scan + personalization + better decisions`
- AI role: `Invisible support layer`
- Retention: `Pantry memory + repeat successful dinners`

That direction fits the repo better than the current hybrid of utility app, AI demo, and gamified cooking identity product.
