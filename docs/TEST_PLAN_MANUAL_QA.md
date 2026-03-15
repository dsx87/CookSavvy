# Manual QA & UI Test Plan

This document defines manual QA scenarios for CookSavvy. Tests marked **[AUTOMATE]** should be implemented as XCUITests in `CookSavvyUITests` target. Tests marked **[MANUAL ONLY]** require human verification (visual, camera hardware, real payments, etc.).

## LLM Implementation Hints

- UI test target: `CookSavvyUITests` (XCUITest framework)
- Use Xcode test plans to organize: create `UITestPlan.xctestplan` targeting `CookSavvyUITests`
- All automated UI tests should use **mock services** — the app uses `AppContainer` singleton with protocol-based DI. In DEBUG builds, mock services are already used for subscription and AI. For UI tests, add a launch argument (e.g. `--uitesting`) that `AppContainer` checks to wire all services to mocks with predictable data.
- Use `app.launchArguments` to control test state (e.g. `["--uitesting", "--skip-onboarding"]`, `["--uitesting", "--fresh-install"]`)
- Accessibility identifiers: the codebase currently lacks them. When implementing UI tests, add `accessibilityIdentifier` to key views in the corresponding SwiftUI view files. Keep identifiers namespaced (e.g. `"discover.searchField"`, `"journey.statsRow.recipesCooked"`).
- For StoreKit UI tests, use the `Configuration.storekit` file already in the project.
- The app has two tabs: Discover (index 0) and Journey (index 1). Navigation is stack-based within each tab, with sheets for shopping list, camera, and upgrade.

---

## 1. Onboarding

### 1.1 First Launch Walkthrough [AUTOMATE]
- Launch app with `--fresh-install` (clear `hasCompletedOnboarding` from AppStorage)
- Verify 3 onboarding screens appear in order
- Swipe through all screens
- Verify app lands on Discover tab after completing onboarding
- Verify re-launching app does NOT show onboarding again

### 1.2 Onboarding Skip Behavior [AUTOMATE]
- Tap through to last screen, complete onboarding
- Verify `hasCompletedOnboarding` is persisted

---

## 2. Discover Tab — Ingredient Selection

### 2.1 Ingredient Search [AUTOMATE]
- Tap search field, type partial ingredient name (e.g. "chic")
- Verify autocomplete results appear
- Tap a result to add it to selected ingredients
- Verify ingredient appears in selection area
- Clear search field, verify results reset

### 2.2 Category Filtering [AUTOMATE]
- Tap a category filter (e.g. Proteins)
- Verify ingredient grid shows only that category
- Tap same category again to deselect, verify all categories return
- Switch between categories, verify grid updates

### 2.3 Ingredient Selection & Removal [AUTOMATE]
- Select multiple ingredients (3+)
- Verify all appear in selection area
- Remove one ingredient
- Verify it's removed from selection

### 2.4 Recent & Saved Ingredients [AUTOMATE]
- Select some ingredients and search for recipes
- Go back to ingredient selection
- Verify recently used ingredients appear in the recent section

### 2.5 Recipe Search Trigger [AUTOMATE]
- Select 2+ ingredients
- Trigger recipe search
- Verify transition to results view
- Verify recipes are displayed

---

## 3. Discover Tab — Recipe Results

### 3.1 Results Display [AUTOMATE]
- Search with known ingredients (mock data should return results)
- Verify hero "best match" card appears at top
- Verify recipe rows appear below
- Verify match percentage is visible on cards

### 3.2 Mood Filter [AUTOMATE]
- On results screen, tap a mood filter (e.g. "Quick")
- Verify recipe order changes (higher-scoring recipes move up)
- Tap same mood to deselect
- Verify original order restores

### 3.3 Use It All Filter [AUTOMATE]
- Toggle the "Use It All" filter on results
- Verify only recipes matching all selected ingredients remain (or list is empty with appropriate messaging)

### 3.4 Suggested Recipes Section [AUTOMATE]
- With mock data that includes favorites and cooking sessions
- Verify suggested recipes section appears on Discover landing
- Verify "Suggested because of X" reason text is shown

### 3.5 Empty State [AUTOMATE]
- Search with ingredients that match nothing in mock data
- Verify empty state / no recipes found messaging

---

## 4. Recipe Details

### 4.1 Detail View Content [AUTOMATE]
- Tap a recipe from results
- Verify recipe title, hero image area, stats row (time, servings, complexity)
- Verify ingredients list is displayed
- Verify steps list is displayed
- Verify "Start Cooking" CTA button exists

### 4.2 Bookmark / Favorite Toggle [AUTOMATE]
- On recipe detail, tap bookmark button
- Verify state changes to bookmarked
- Tap again, verify unbookmarked
- Navigate to Journey tab, verify bookmarked recipe appears in saved

### 4.3 Add Missing Ingredients to Shopping List — Premium [AUTOMATE]
- As premium user (mock), open recipe with missing ingredients
- Tap "Add Missing to List"
- Verify shopping list sheet opens with items added
- Verify items have recipe title association

### 4.4 Add Missing Ingredients — Free Tier Gate [AUTOMATE]
- As free user (mock), tap "Add Missing to List"
- Verify upgrade prompt appears

### 4.5 Navigate to Cook Mode [AUTOMATE]
- Tap "Start Cooking" CTA
- Verify cook mode opens as full screen cover

---

## 5. Cook Mode

### 5.1 Step Navigation [AUTOMATE]
- Enter cook mode for a recipe with 3+ steps
- Verify first step is displayed with step number
- Tap "Next" to advance
- Verify step content updates
- Tap "Previous" to go back
- Verify step content reverts
- Verify progress ring updates with each step

### 5.2 Timer Functionality [MANUAL ONLY]
- Enter cook mode on a step that has a timer (e.g. `timerMinutes: 5`)
- Verify timer UI appears
- Start timer, verify countdown begins
- Wait a few seconds, verify countdown progresses
- **Why manual:** Timer accuracy and real-time countdown verification requires human observation. Automation can verify timer UI exists but not real-time behavior.

### 5.3 Cook Mode Completion [AUTOMATE]
- Navigate through all steps to the last one
- Complete the recipe
- Verify cook mode dismisses
- Verify a cooking session is recorded (check Journey tab stats)

### 5.4 Cook Mode Dismiss [AUTOMATE]
- Enter cook mode, navigate to step 2
- Dismiss cook mode (back/close button)
- Verify return to recipe details

---

## 6. Create Recipe

### 6.1 Full Wizard Flow [AUTOMATE]
- Navigate to Create Recipe
- Step 1: Enter recipe name
- Step 2: Add 2+ ingredients
- Step 3: Add 2+ steps
- Step 4: Set details (time, servings, complexity)
- Step 5: Review and save
- Verify recipe appears in Journey tab under user recipes

### 6.2 Wizard Validation [AUTOMATE]
- Try to advance from Step 1 without a name — verify blocked/error
- Try to save without ingredients — verify blocked
- Try to save without steps — verify blocked

### 6.3 Edit/Delete User Recipe [AUTOMATE]
- Create a recipe via wizard
- Find it in Journey tab
- Verify it can be opened and details match what was entered
- Delete the recipe
- Verify it's removed from the list

---

## 7. Journey Tab

### 7.1 Stats Display [AUTOMATE]
- With mock data (sessions, favorites, user recipes)
- Verify profile header area exists
- Verify stats show: recipes cooked count, day streak, cooking hours

### 7.2 Weekly Calendar [AUTOMATE]
- With mock data where cooking happened on specific days
- Verify weekly calendar shows correct highlighted days (0-6)

### 7.3 Achievements Display [AUTOMATE]
- Verify all achievements are listed
- With mock data where some achievements are unlocked
- Verify unlocked achievements show visually distinct from locked
- Verify progress fractions are correct

### 7.4 Recent Sessions [AUTOMATE]
- Verify recent cooking sessions list appears
- Verify sessions show recipe title and date
- Tap a session to navigate to recipe details

### 7.5 Navigation to Settings [AUTOMATE]
- Tap gear icon in nav bar
- Verify Settings screen opens

---

## 8. Shopping List

### 8.1 CRUD Operations [AUTOMATE]
- Open shopping list (from recipe details or Journey)
- Add items from a recipe
- Verify items appear grouped by recipe title
- Toggle item checked state
- Verify visual change (strikethrough/check)
- Clear completed items
- Verify only unchecked items remain

### 8.2 Swipe to Delete [AUTOMATE]
- Swipe an item to delete
- Verify item is removed
- Verify other items remain

### 8.3 Premium Gate [AUTOMATE]
- As free user, attempt to access shopping list
- Verify upgrade prompt appears

---

## 9. Camera & Ingredient Detection

### 9.1 Camera Launch — Free Tier [MANUAL ONLY]
- As free user, open camera for ingredient detection
- Verify camera viewfinder appears on physical device
- **Why manual:** Requires real camera hardware, simulator cannot test camera capture.

### 9.2 Camera Scan Limit — Free Tier [AUTOMATE partial + MANUAL]
- **[AUTOMATE]**: Verify remaining scan count displays correctly, verify that after 5 mock scans the UI shows limit reached, verify upgrade prompt appears.
- **[MANUAL ONLY]**: Actually capture a photo and verify ingredient detection results on physical device with real camera.

### 9.3 Camera — Premium Unlimited [MANUAL ONLY]
- As premium user, verify no scan limit messaging
- Capture multiple photos, verify detection works each time
- **Why manual:** Real camera + AI detection pipeline requires physical device and API keys.

### 9.4 AI Ingredient Detection Results [MANUAL ONLY]
- Take photo of actual ingredients on a table
- Verify detected ingredients are reasonable
- Verify detected ingredients can be added to selection
- **Why manual:** AI detection quality is non-deterministic and requires real image input.

---

## 10. Subscription & Upgrade

### 10.1 Upgrade Screen Display [AUTOMATE]
- Trigger upgrade prompt (e.g. tap premium feature as free user)
- Verify upgrade screen shows plan name (CookSavvy+)
- Verify price is displayed
- Verify feature list is shown

### 10.2 Purchase Flow [MANUAL ONLY]
- In StoreKit sandbox environment on device
- Tap purchase button
- Complete sandbox purchase
- Verify plan updates to premium
- Verify premium features become accessible (camera unlimited, shopping list, online/AI recipes)
- **Why manual:** StoreKit sandbox purchase requires Apple ID interaction and real payment sheet.

### 10.3 Restore Purchase [MANUAL ONLY]
- After purchasing, reinstall or clear data
- Tap "Restore Purchases"
- Verify premium access is restored
- **Why manual:** Requires actual StoreKit transaction history.

### 10.4 Feature Gating Verification [AUTOMATE]
- As free user, verify each `PaidFeature` enum case is gated:
  - `cameraIngredientDetection` — limited to 5/week
  - `onlineRecipes` — source unavailable
  - `aiRecipes` — source unavailable
  - `shoppingList` — shows upgrade prompt
- As premium user (mock), verify all above are accessible

---

## 11. Settings

### 11.1 Settings Display [AUTOMATE]
- Open Settings from Journey nav bar
- Verify subscription plan is shown
- Verify usage limits are displayed (for free tier)
- Verify preferences section exists

### 11.2 Theme Preference [MANUAL ONLY]
- Switch theme preference
- Verify app appearance changes
- **Why manual:** Visual theme verification requires human eyes. Automated tests can verify the setting is persisted but not that colors actually changed.

### 11.3 Clear Data [AUTOMATE]
- Tap clear recent data
- Navigate back, verify recent ingredients/recipes are cleared
- Verify favorites still exist (separate action)

---

## 12. Offline Behavior [MANUAL ONLY]

### 12.1 Offline Recipe Search
- Put device in airplane mode
- Search for recipes with ingredients
- Verify offline recipes still return results (from local DB)
- Verify no crash or hang

### 12.2 Online Source Graceful Failure
- With premium account, in airplane mode
- Search for recipes
- Verify offline results appear
- Verify online/AI sources show appropriate unavailable state (no crash)

**Why manual:** Network condition testing is unreliable to automate and requires real device network toggling.

---

## 13. Edge Cases & Stability [AUTOMATE where noted]

### 13.1 Empty Database State [AUTOMATE]
- Launch with empty DB (before initialization completes)
- Verify app doesn't crash
- Verify loading state or empty state is shown

### 13.2 Rapid Navigation [AUTOMATE]
- Quickly switch tabs multiple times
- Push and pop views rapidly
- Verify no crashes

### 13.3 Background/Foreground [MANUAL ONLY]
- Start a cooking session
- Background the app
- Return after 30 seconds
- Verify cook mode state is preserved
- **Why manual:** App lifecycle testing is hard to automate reliably.

### 13.4 Large Data Sets [AUTOMATE]
- With mock data containing 100+ recipes and 50+ ingredients selected
- Verify search and results load without hang
- Verify scrolling is smooth (manual visual check if needed)
