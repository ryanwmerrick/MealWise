# Phase 3 — setup and a saved budget-locked week

Implemented eight real setup steps, Back/summary edits and a persisted draft; all selections feed the planner. Dates are real calendar dates, household portions use the approved development convention, time/skill/diet/allergy constraints filter before search, and the synthetic store has no fictitious distance or search integration.

Planning runs on an actor with cancellation and a 20,000-node deterministic search bound. Whole-package rounding happens after household-scaled requirements are consolidated. A complete feasible plan is returned only when its checkout total fits the cap; exhaustion is distinct from a bounded search finding no result. Within the visited feasible candidates, diversity is preferred, then lower checkout cost, then lower unused package value for equal-cost options. This is not a guarantee of global optimality.

The committed immutable snapshot contains profile, catalog/offer version, meals, cart and revision. Saving writes active plan and profile in one SwiftData transaction; restoring recalculates and validates the cart. Existing saved estimates remain readable after their price dates expire, while new generation rechecks current price freshness.

Week uses a pinned native safe-area budget card, real meals, household ingredient consumption estimates and ingredient-sharing counts. Budget details distinguish whole-package checkout allocation from consumed ingredient cost. Settings includes store/food inputs, creates an explicit replacement preview, and saves only on acceptance. Reset requires a native destructive confirmation. Failed or infeasible generation preserves the saved plan and offers editable recovery choices.

User-authorized missing designs reuse the established card, green/gold palette, typography and native presentation. Development recipes and prices are labeled visibly. Ingredient metadata is unverified, so allergy and gluten-free requirements fail closed; the UI explains this limitation.

Regression coverage includes exact-cap/one-cent-over, the 6,430/7,000-cent fixture with 570 cents remaining, shared package aggregation, three meal slots, unknown allergens, explicit gluten-free eligibility, bounded search, cancellation, atomic save/restore, invalid budget, Back/summary editing, retained same-session drafts, old selected dates and failed-save preview recovery. UI coverage exercises all setup steps, summary Edit, generation, four tabs, relaunch and settings, plus Welcome accessibility/large text.

Independent review identified three issues (draft state on reentry, invisible prior dates, gluten-free certification bypass). They were fixed with regression coverage. During integration, the UI reset helper needed to scroll the native settings list before tapping its offscreen reset action; no production action was bypassed for tests. No test-specific production launch mode or storage bypass is included.

Final verification: `/private/tmp/mealwise-phase3-clean.log` reports `BUILD SUCCEEDED` and `TEST SUCCEEDED`: 37 Swift Testing tests and five UI tests, zero failures. Results: `/private/tmp/mealwise-phase3-final-clean.xcresult`. The suite uses `-collect-test-diagnostics never -parallel-testing-enabled NO` after Xcode stalled finalizing verbose diagnostics on an earlier passing run. Interrupted commands are not counted as clean verification.

A restored dark-mode Week screenshot was inspected on iPhone 17e: estimates, development notice, real scaled meal costs, shared ingredient counts and native tabs render correctly. The header uses the compact native title to keep the pinned meter and scrolling meals usable. Hardware VoiceOver listening remains a release check.
