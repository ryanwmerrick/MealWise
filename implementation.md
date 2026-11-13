# MealWise Implementation Plan

## App summary

MealWise is a free, budget-first iOS meal planner for lower-income households, SNAP recipients, students, and beginner cooks. Users set a grocery spending cap and practical preferences, receive meals that share whole grocery packages, shop from one priced list, and follow simple recipes. Later increments add safe swaps, actual spending, cooking support, wrap-up, pantry carryover, favorites, nutrition balance, and optional cross-device accounts.

**Goal:** Deliver the complete MVP1–MVP4 weekly cycle: Set Budget → Plan → Reuse → Shop → Cook → Wrap Up → Carry Over.

**Architecture:** Native SwiftUI with feature-based MVVM, protocol-injected services, SwiftData persistence, and a deterministic, package-aware local planner. One committed plan is the source for meals, cart, budget, and ingredient allocations. Optional account synchronization arrives only after the local cycle works.

**Tech stack:** Swift 6 with strict concurrency, SwiftUI, SwiftData, Swift Testing, XCTest UI tests, and Keychain for credentials. Use URLSession only when an approved remote service is introduced.

**Sources:** Read `CLAUDE.md` and `project_description.md` in full. Design source: [MealWise UI in Figma Make](https://www.figma.com/make/BJT2UHwHtxyVbn1ryrLWA4/MealWise-UI?t=wbZ3ZrEfQZNb617W-0), accessed through Figma MCP on November 11, 2026. Layout, visuals, and screen structure follow Figma; behavior and business rules follow the description.

**Execution:** This document authorizes no implementation. When implementation is requested, use Superpowers executing-plans phase by phase. Each phase consumes only completed dependencies and ends with a runnable app and passing checks. Do not build future-phase functionality early.

## Design evidence and screen inventory

Figma MCP `get_design_context` returned the Make project's source resources. The complete `src/App.tsx` and `src/index.css` were inspected. `create_session` and `get_screenshot` returned “not supported for Make files”; `get_variable_defs` explicitly supports Design files only. Consequently, this inventory and the tokens below are extracted from the actual Make implementation, not inferred frames or a visually verified screenshot. No stable per-screen frame IDs were supplied. References below name actual Make functions and CSS selectors under file key `BJT2UHwHtxyVbn1ryrLWA4`; `0:1` is the Make context entry point, not an invented screen frame.

| Reference in `src/App.tsx` | Screen / state | Purpose and navigation |
| --- | --- | --- |
| `Welcome` | Welcome | Receipt illustration, budget-first introduction, “Plan my week”; opens setup. |
| `Onboarding`, `SetupControl(kind: budget)` | Setup 1/8 | Numeric budget and $40/$55/$70/$90 presets. |
| `SetupControl(kind: people)` | Setup 2/8 | Adult age 13+ and child age 2–12 counters. |
| `SetupControl(kind: days)` | Setup 3/8 | Seven weekday buttons and Dinner/Lunch/Breakfast choices. |
| `SetupControl(kind: time)` | Setup 4/8 | ≤15 minutes, about 30, up to 45, flexible. |
| `SetupControl(kind: skill)` | Setup 5/8 | Beginner, Comfortable, Experienced. |
| `SetupControl(kind: store)` | Setup 6/8 | Store/ZIP search presentation and store choices with distances. |
| `SetupControl(kind: diet)` | Setup 7/8 | Allergy and preference chips. |
| `SetupControl(kind: summary)`, `Summary` | Setup 8/8 | Review answers with Edit actions; “Build my plan.” |
| `BuildingPlan` | Plan generation | Dark green progress view, ingredient orbit labels, package-checking status. |
| `WeekScreen` | Week tab / home | Budget card, daily meal rows, swap buttons, Map link, leftover card, settings. |
| `GroceryScreen(shopping: false)` | Groceries tab | Produce/Meat & dairy/Pantry sections, package quantities, prices, checkboxes, Start shopping. |
| `GroceryScreen(shopping: true)` | Shopping state | Same screen with checked-item count, running total, editable prices, Done. Tabs remain visible in Make. |
| `TodayScreen` | Today tab | Tonight's meal, serving cost, time/skill, “Before you start,” ingredient chips, skip and cooking actions. |
| `CookMode`, `cookSteps` | Full-screen cooking | Three sample steps, progress, close and timer controls, save-for-later notes; final Mark as cooked. Tabs hidden. |
| `PantryScreen` | Pantry tab | Savings banner, four sample pantry items, add/detail affordances, Plan next week. |
| `IngredientMap` | Pushed ingredient view | Fully used/carry over/at risk counts; package rows, usage bars, weekday badges. Back returns to Week; tabs hidden. |
| `SheetView(type: budget)` | Budget detail / adjustment sheet | Budget, estimate, remainder, per-day/per-serving statistics, $40–$100 slider, confirmation. |
| `SheetView(type: swap)` | Swap sheet | Three sample replacements, selected state, price delta/new total, reuse count, Cart impact, confirmation. |
| `SheetView(type: settings)` | Settings sheet | Budget, household, schedule, cooking, food needs, Start over. |
| `SheetView(type: price)` | Actual price sheet | Item-specific price input, budget feedback, Update price. |

**Navigation:** Welcome → eight setup steps with Back → Building → Week. Main tabs are Week, Groceries, Today, Pantry. Week opens budget/settings/swap sheets and pushes Ingredient Map. Groceries enters Shopping and opens Price Edit. Today enters full-screen Cook Mode. Make currently routes only the first Week meal directly into Cook Mode; implement the description's Meal Detail flow once its missing design is supplied.

**Reusable components and observed states:** `Icon`, `Counter`, `ChoiceList`, `Summary`, `TabBar`, sheet container, primary/secondary/icon buttons, budget/progress meters, meal rows, grocery rows, ingredient chips, reuse badges, save notes, savings and leftover cards. Existing states include selected/unselected choices and swaps, active/inactive tabs, checked/unchecked groceries, normal/shopping mode, generation progress, and cooking step progress. Empty, error, retry, disabled, infeasible-plan, over-budget, completed-week, and persistence failure presentations are not designed. Do not treat their absence as permission to omit behavior.

## Design tokens and assets for Phase 1

Values below come from `src/index.css`; web pixel sizes are reference values to map to scalable native text and layout tokens, not fixed device dimensions.

| Token family | Extracted values / use |
| --- | --- |
| Surfaces | Main `#F7F8F4`; welcome `#EFF3E9`; setup `#FAFBF8`; sheet `#F9FAF7`; cards `#FFFFFF`. |
| Text | Primary `#17231F`; supporting `#65736D` and related muted greens; action `#126B4C`. |
| Brand | Primary button `#106B4B`; strong green `#176D4F`; dark panels/build/cook `#173F32`. |
| Accent | Meter gold `#F0BD4F`; cook gold `#EFC260`; eyebrow amber `#9B5B12`. |
| Selection | Chip `#E1F0E7`, border `#69A88E`; choice `#EFF7F2`, border `#3C8B6E`. |
| Borders / notes | Standard `#DCE3DE` / `#DFE5E0`; save-note fill `#FFF5DC`, border `#EAD49B`, text `#694B16`; leftover fill `#EDF6EF`. |
| Meal art | Gold `#D09A30`, red `#B7553E`, green `#5E8451`, blue `#557A85`, orange `#C46E3C`. |
| Typography | Apple system / SF Pro Text; welcome headline 40/800, setup/cook headline 32, main title 30/760, sheet title 27, hero title 24, section 18, body/instructions 16–17, rows 13–14, metadata 10–12, budget numeral 35, setup numeral 72. Receipt eyebrow uses system monospace. Use Dynamic Type styles and scaled metrics. |
| Spacing | Common gaps 8/10/12/16; horizontal screen inset 20, setup/sheets 22, welcome 24; card padding 12–18; section separation 20–25. |
| Radius | Buttons 16–17; choices 17; counters/notes 18; banners 20; budget 23; hero 24; sheet top corners 30; icon circles. |
| Controls | Primary minimum height 54, secondary 50, icon buttons 44; enlarge smaller visual checkboxes and swap controls to ≥44×44 hit areas. |
| Motion | Progress transitions around 0.3s, sheet fade 0.18s/rise 0.25s; generation pulse. Respect Reduce Motion and use native sheet transitions. |

**Assets:** `Icon` defines 21 custom outline glyphs: arrow, back, basket, calendar, check, chevron, clock, close, leaf, list, minus, pantry, plus, pot, refresh, settings, spark, swap, timer, wallet. Preserve the supplied glyph geometry in native vector assets where needed; do not silently substitute visually different symbols. Welcome receipt/produce, meal tiles, and cooking illustrations are CSS/vector compositions rather than recipe photos. Recreate those compositions with SwiftUI shapes using the source as reference. MCP lists four PNG resources (`67f1879aec267c4c054b158ed8ab284f88ad62b9.png`, `7b5ff1f1a8cb0091b216b565731d648adb85a66f.png`, `b38086d929ee0d49525bf40b7f1aa6cea940a27d.png`, `fc48b385a6704ba2574a2397cbd00a4b56467c9b.png`) plus `public/favicon.png`; the inspected App does not reference them. Confirm their intended role before importing them. No external font or photo dependency is shown.

The fixed 390×844 phone, simulated status bar, home indicator, outer gradient, and device border are presentation scaffolding. Native iOS uses real safe areas and system chrome. Dark-mode token counterparts are missing and require design review.

## Reconciliation: mismatches and open questions

### Description features missing or incomplete in Make

| Gap | Required handling / owning phase |
| --- | --- |
| Meal Detail with full ingredients, numbered recipe, nutrition and linked meals | Missing distinct screen; obtain design before Phase 4 UI. |
| Ingredient Detail timeline and quantities per meal | Map rows have no action; obtain design before Phase 5 UI. |
| Persistent Budget Meter | Week card scrolls with content; agree pinned/native placement before Phase 3 UI. |
| Real planning, allergy filtering, package costing, infeasible recovery, persistence | Prototype uses constants and a 1.3-second timeout; implement in Phases 2–3. |
| Functional setup/settings | Several controls are decorative; selected choices do not form a persisted profile, summary is mostly fixed, Edit/settings rows are inert. Phases 2–3 must use actual values. Store is absent from settings rows. |
| Multi-meal/day planning, dietary combinations, full catalog coverage | Make shows five dinners and limited chips; description behavior wins. Phase 2 validates supported combinations; Phase 3 supports genuine selections. |
| Swap target, dynamic cart impact, over-budget reveal, exclusions, day/week regeneration | Every swap opens Wednesday's static sheet; Phase 6 supplies actual selected-meal behavior and missing control designs. |
| Budget re-optimization and before/after acceptance | Slider changes a number without changing plan; Phase 6 needs comparison design. |
| Perishable risk and actionable leftover suggestions | Static “Nothing wasted” card opens Map; Phase 5 supplies real forecast and Phase 6 suggested swaps. |
| Shopping completion summary, actual spending, cheaper substitutes | Done only exits shopping; all price edits show turkey and fixed feedback. Phase 7 supplies real transactions and missing states. |
| Cook completion, timers, skipped-meal rescheduling | Final action only closes; timer and skip controls inert. Phase 8 supplies behavior and missing presentations. |
| Wrap-Up, leftover confirmation, next-week setup, pantry add/edit/remove | Mostly absent; Phase 9 requires designs. |
| Ratings, Favorites/pinning, weekly nutrition, optional account/sync | Absent; Phase 10 requires designs and account decisions. |
| PLUS overview, comparison, SNAP eligibility, tips, advanced AI | Absent and explicitly future scope in the description; excluded from these MVP1–MVP4 phases. |

### Design-specific additions and conflicts

- Four-tab navigation, ingredient orbit animation, receipt illustration, exact presets, adult/child age labels, ZIP search and store distances are design details not specified in equivalent detail by the description. Preserve the visual structure; distances require a real data source before displaying them as factual.
- Shopping retains tabs in Make, while the description calls it full-screen. Figma wins for structure: retain the tab-based shopping state unless the design is revised.
- Sample prices are inconsistent: the five meal costs sum to $30.24; the ten grocery entries sum to $29.32; the shown weekly total is $64.30. These are illustrative values, not a production dataset. Package checkout cost and ingredient consumption cost must be labeled separately.
- The Week footer says “$4.29 avg. per meal,” while the budget sheet labels the same figure “per serving.” Resolve labels and allocation definitions before Phase 3; never derive checkout totals by adding illustrative recipe figures.
- The 30-minute sample profile includes a 35-minute meal. Time filtering follows the description, not that sample.
- Make cannot supply screenshots/variables through the available tools. Source inspection succeeded, so the design is accessible, but visual comparison against a rendered Make preview remains a Phase 1 verification dependency.

### Open decisions and gates

1. **Missing design:** Supply layouts/states for the absent screens listed above, infeasible/error/empty states, before/after comparisons, over-budget warnings, and dark mode before their owning phase's UI is implemented. Reuse existing components only where the supplied design establishes their layout; do not invent unseen screens.
2. **Catalog and prices:** Who owns recipe authorship, tested instructions, ingredient/allergen review, launch catalog size, regional package prices, and refresh cadence? Phase 2 requires a reviewed launch dataset with provenance and price dates. No plan can guarantee actual checkout prices from estimates.
3. **Budget accounting:** Do caps include tax, deposits, fees, and optional staples? How should package costs be allocated into meal/day/serving displays? Phase 2 must record an explicit accounting policy before the planner is built.
4. **Portions and constraints:** Confirm child portion scaling, households with no adults, under-two household members, permitted days/meal slots, time strictness, supported allergies, equipment limitations, and unit conversions. Unknown allergens must never be treated as safe. These affect Phase 2 validation and catalog coverage.
5. **Stores:** Which stores/regions launch, one or multiple stores per plan, whether selection affects prices or section order, and what powers ZIP search/distances? No MapKit/location permission is assumed; geographic maps are not required by the Ingredient Map.
6. **After shopping:** Decide how budget/profile edits, swaps, and pantry updates interact with purchased stock and cooked meals. Proposed rule: preserve history and purchased quantities; preview changes only to remaining meals. Resolve before Phase 6; exercise actual-price interactions again in Phase 7.
7. **Over-budget reveal:** The description permits viewing over-budget swaps but promises a hard cap. Proposed behavior: reveal for comparison with a warning; confirmation remains unavailable until an explicit budget change produces a feasible plan. Confirm before Phase 6.
8. **Carryover and safety:** Define storage/expiry metadata, how users confirm remaining quantities, and how missed meals affect stock. Avoid presenting an inferred spoilage forecast as a guarantee of safety. Resolve before Phases 5/8/9.
9. **Accounts:** Choose provider/backend, account lifecycle, guest-data merge, conflict behavior, offline queue, deletion and retention before Phase 10. CloudKit is a possible Apple-only option but does not itself settle the requested in-app account experience. No provider is silently selected.
10. **Platform/toolchain:** User request settles iOS. `CLAUDE.md` specifies iOS 27.0+ and Swift 6; verify the installed SDK/simulator supports that deployment target before Phase 1. Do not silently lower it.
11. **Future commerce:** PLUS price, monetization, SNAP verification/privacy, and tips remain deferred product decisions. Free core planning and no mandatory account/payment remain requirements.

These questions are deliberately recorded rather than answered by hidden assumptions. A gate blocks only dependent work; completed local phases remain runnable. Full-project completion cannot be claimed while an owning phase's design, content, or service gate remains unresolved.

## Technical approach and global constraints

The description already recommends curated recipes and estimated regional prices. A deterministic local planner is the proposed baseline: predictable, offline-capable, and straightforward to verify. A live retailer service would add availability, licensing, and price-freshness dependencies; AI generation would add nondeterminism and require independent validation of every recipe and cost. Neither is needed for the initial cycle. These are planning recommendations, not recorded user approvals.

- Follow `CLAUDE.md`: feature folders, SwiftUI-first, `NavigationStack` with value routes, native sheets/tab chrome, no hand-built glass or device frame.
- Feature ViewModels: `@MainActor final class`, `ObservableObject`, `@Published`, owned by `@StateObject`; shared app/session state: one root-created `@Observable` instance with typed environment injection. No `@EnvironmentObject`.
- Protocol services receive dependencies in initializers. Start async work from `.task`; respect cancellation and keep computation/storage work off the main actor. No network/disk work in ViewModel initializers.
- Use integer minor currency units with a currency code and explicit display rounding. Quantities use normalized units and defined conversions; never treat a volume-to-mass conversion as universal.
- Filter hard constraints before optimizing. Price the consolidated cart using whole-package rounding after aggregation. Prefer lower waste and ingredient reuse among feasible plans; never silently relax allergies, household coverage, or budget.
- Use bounded deterministic search over the curated catalog. A search limit produces a distinct “no plan found” result, not a false assertion that no feasible plan exists. Return a recoverable explanation, never a partial plan masquerading as success.
- Commit plan/profile/cart changes atomically after validation. Preview operations do not mutate the active plan. Revalidate the plan revision on acceptance to prevent stale previews.
- SwiftData stores profiles, plan snapshots, shopping/cooking progress, then pantry/history as introduced. Single-source derived projections prevent conflicting totals. Use in-memory stores in tests and migration coverage when schemas change.
- No camera, AI, HealthKit, retailer API, location, payment SDK, or generic backend scaffolding without a concrete phase requirement. Future remote clients use injected URLSession, checked HTTP status, Codable, environment `.xcconfig`, domain errors, and private logging. Secrets never ship as client-embedded service credentials.
- Every phase includes localization, VoiceOver, ≥44-point hit areas, Dynamic Type, adaptive layouts, and state previews; dark-mode appearance follows reviewed tokens. No user-facing strings assembled by concatenation.

**Verification convention:** Phase 1 creates the `MealWise` shared scheme, app/unit/UI test targets, and project. Select an available iOS 27+ simulator UUID with `xcrun simctl list devices available`. Thereafter run `xcodebuild -project MealWise.xcodeproj -scheme MealWise -destination 'platform=iOS Simulator,id=<available-UUID>' build` and the equivalent `test` command. Expected results: `BUILD SUCCEEDED`, `TEST SUCCEEDED`, no failing tests, and no strict-concurrency errors. Run the owning phase's focused tests while iterating and the full suite at the phase gate. No such build is claimed in this planning-only deliverable.

**Review focus:** Fractional-cent/package-boundary calculations (Phases 2/4); empty or incompatible profiles and unknown allergens (Phases 2/3); cancelled/stale changes and failed saves (Phases 3/6); actual overspend and partial shopping (Phase 7); duplicate completion/carryover and offline sync conflicts (Phases 8–10).

## Phase 1 — Native foundation and design vocabulary

**Goal:** Establish a buildable native shell and reusable visual foundations without product logic.

**Scope / files:** Create `MealWise.xcodeproj`, `MealWise/App/MealWiseApp.swift`, `App/RootView.swift`, `App/AppRoute.swift`, `Shared/Constants/DesignTokens.swift`, `Shared/Components/` button/row/meter primitives, `Resources/Assets.xcassets`, `Resources/Localizable.xcstrings`, `Resources/PrivacyInfo.xcprivacy`, and mirrored test targets. Add only the Welcome entry and tab shell needed for previews/development; do not expose invented functional destinations.

**Figma references:** `Welcome`, `TabBar`, `Icon`, shared buttons; CSS token families above. Native chrome follows project rules while content follows Make.

- [ ] Confirm SDK availability, project settings, bundle/signing configuration, and simulator target.
- [ ] Establish the feature directory structure, Swift 6 checks, shared scheme and test targets.
- [ ] Implement tokens, referenced vector art, Welcome, and isolated component state previews.
- [ ] Compare a rendered Make preview with native previews; obtain dark-mode/missing-state design decisions needed now.

**Definition of Done:** App launches into the designed Welcome on a supported simulator, components scale, native safe areas work, and all assets have identified uses. No fake plan or pretend integration is presented.

**Verification:** Build and test using the convention above. UI smoke test launches Welcome and activates its primary action into the shell. Manually inspect small/large/resized layouts, accessibility text sizes, VoiceOver labels, contrast, Reduce Motion, and reviewed light/dark variants.

## Phase 2 — Reviewed data, money, quantities, and local persistence

**Goal:** Supply trustworthy inputs and storage for budget-aware planning.

**Scope / files:** `Core/Models/{Money,Quantity,PlanningProfile,Recipe,Ingredient,PackageOffer}.swift`; `Core/Catalog/{CatalogService,CatalogValidator}.swift`; `Core/Persistence/{LocalStore,ProfileRepository}.swift`; `Resources/Catalog/` reviewed JSON; `MealWiseTests/Core/`. Add model types only as needed here; no future sync/pantry implementation.

**Figma references:** Setup controls/summary and package/price fields in `GroceryScreen` and `IngredientMap` define the data to support; no new feature screen.

**Interfaces:** `CatalogServiceProtocol.loadCatalog() async throws -> RecipeCatalog`; `ProfileRepositoryProtocol.loadProfile() async throws -> PlanningProfile?`; `saveProfile(_ profile: PlanningProfile) async throws`. Recipes and offers use stable IDs; profile contains budget, adults/children, dates/meal slots, time, skill, stores and food constraints.

- [ ] Resolve catalog, portion, accounting, allergen and store gates; record the supported launch combinations and metadata.
- [ ] Write unit tests for money parsing/rounding, unit conversions, validation and save/reload failures before implementing services.
- [ ] Add reviewed recipes with quantities, package offers, allergens, time/skill, steps and simple nutrition indicators.
- [ ] Implement catalog validation and SwiftData profile persistence; surface failures through typed errors.

**Definition of Done:** Invalid or incomplete catalog entries cannot enter planning. Profiles round-trip locally. Price provenance is available, unsupported conversions fail explicitly, and the app still launches.

**Verification:** `moneyDoesNotUseBinaryFloatingPoint`, `packageBoundaryRoundsUp`, `unknownAllergenIsNotSafe`, `invalidHouseholdRejected`, `incompatibleUnitsRejected`, and `profileRoundTrips` pass. For a synthetic fixture, 501 g required in 500 g packages at 249 cents/package requires two packages and 498 cents. Run full build/tests; inspect catalog validation output and relaunch persistence manually.

## Phase 3 — Complete setup and a budget-locked weekly plan

**Goal:** Deliver genuine onboarding, persisted preferences and feasible weekly generation.

**Scope / files:** `Features/Onboarding/`, `Features/Week/`, `Features/Settings/`; `Core/Planning/{PlanRequest,PlanOutcome,PlanService,CartCalculator}.swift`; `Core/Persistence/PlanRepository.swift`; `App/RootView.swift`; matching tests.

**Figma references:** All eight `Onboarding`/`SetupControl` states, `Summary`, `BuildingPlan`, `WeekScreen`, settings and budget variants of `SheetView`. Resolve pinned meter placement and missing recovery layouts before UI work.

**Interfaces:** `PlanServiceProtocol.generate(_ request: PlanRequest) async throws -> PlanOutcome`; outcomes distinguish feasible, invalid inputs, no feasible solution, and search limit. `PlanRepositoryProtocol.loadActivePlan() async throws -> WeeklyPlan?`; `saveActivePlan(_ plan: WeeklyPlan) async throws`. Plans retain profile/catalog/offer versions and stable revision IDs.

- [ ] Test hard filters and whole-cart costing, then implement deterministic generation with cancellation and a defined work bound.
- [ ] Wire every setup input and summary Edit action to one persisted profile draft; preserve answers on Back.
- [ ] Generate actual requested dates/meal slots, household portions and shared ingredients; commit only complete validated results.
- [ ] Render Week and read-only budget detail from the committed plan. Settings edits regenerate through preview/accept; Start over requires the supplied reset presentation.

**Definition of Done:** A guest can enter real preferences and receive a saved, complete plan whose estimated purchase total is ≤ budget. No suitable result leaves an actionable recovery state without destroying an existing plan. Relaunch restores the plan. Budget adjustment optimization and swaps remain Phase 6.

**Verification:** Test exact-cap success, one-cent-over rejection, all candidate recipes filtered, multiple meal slots, shared-package cost, search limit distinct from infeasibility, cancellation and failed save. Synthetic assertion: a 7,000-cent cap accepts a 6,430-cent cart and displays 570 cents remaining. UI test completes all setup steps, edits an answer, builds, relaunches and opens settings; manually check validation/keyboard and a profile that has no feasible plan. Run full build/tests.

## Phase 4 — Consolidated groceries and usable recipes (MVP1 complete)

**Goal:** Make the generated week usable for shopping and cooking without an account.

**Scope / files:** `Features/Groceries/`, `Features/MealDetail/`, `Core/Planning/PlanCostBreakdown.swift`, and matching tests. Extend plan projections rather than keeping independent cart totals.

**Figma references:** `GroceryScreen(shopping: false)`, `WeekScreen` meal rows, `TodayScreen` hero/ingredient visual vocabulary. **Gate:** full Meal Detail layout is absent; obtain it before building that screen. Every meal row opens its own detail, following the description.

**Interfaces:** `CartCalculator.calculate(_ request: CartRequest) throws -> PricedCart` is the common package calculation used by Phase 3 and all later previews. `MealDetailView` takes a plan ID and meal ID; its ViewModel loads the same committed plan revision.

- [ ] Test ingredient aggregation and package rounding across recipes, then derive categorized grocery rows and totals.
- [ ] Implement saved checklist state, package counts/sizes, estimate labels and approved cost attribution labels.
- [ ] Implement every meal's ingredients, scaled servings, numbered skill-appropriate steps, time and nutrition balance.
- [ ] Connect Week → Recipe and Groceries with stable IDs and empty/error recovery states.

**Definition of Done:** The user can plan, inspect any recipe, shop from a consolidated priced list and relaunch without losing progress. Cart and budget always reconcile; recipe consumption costs are clearly distinguished from checkout cost. No shopping-price editing or step mode yet.

**Verification:** Test repeated ingredient merge, multiple required packages, zero-cost owned staples only under the approved policy, recipe quantity scaling and checklist restoration. UI test opens each planned meal and checks a grocery item. Manually follow one complete recipe against its cart and household quantities; inspect price provenance and offline behavior. Run full build/tests.

## Phase 5 — Ingredient accountability and leftover forecasts

**Goal:** Explain where every purchased quantity goes and what remains.

**Scope / files:** `Features/Ingredients/{Views,ViewModels,Models}/`, `Core/Planning/IngredientAllocationService.swift`, forecast models and matching tests.

**Figma references:** `IngredientMap`, `WeekScreen` leftover card, `TodayScreen` save-note styling. **Gate:** Ingredient Detail timeline, at-risk states and actionable forecast layouts require supplied designs.

**Interfaces:** `IngredientAllocationServiceProtocol.allocate(plan: WeeklyPlan) throws -> IngredientAllocationReport`; report contains purchased quantity, allocations by meal/date, remaining quantity, staple/perishable status and forecast reasons.

- [ ] Test quantity conservation and allocation chronology before implementing the report service.
- [ ] Implement all-package Map rows and real fully-used/carryover/risk summaries.
- [ ] Implement Ingredient Detail → Meal Detail navigation using actual quantities and dates.
- [ ] Derive use-now/save-for-later recipe notes and perishable forecasts; simple usage suggestions appear here, swap actions connect in Phase 6.

**Definition of Done:** Every cart item is accounted for, with no negative remainder or invented “fully used” claim. Recipes show reservations for later meals; forecast uncertainty is visible where relevant.

**Verification:** Test `purchasedEqualsAllocatedPlusRemaining`, incompatible units, multi-package allocations, staples versus perishables and changed meal order. UI test Week → Map → Ingredient → Meal; manually reconcile a package used by three meals and a partly used perishable. Run full build/tests.

## Phase 6 — Safe swaps, budget changes and regeneration (MVP2 complete)

**Goal:** Let users change a week while preserving budget and ingredient consistency.

**Scope / files:** `Features/Swaps/`, budget/settings extensions, `Core/Planning/PlanChangeService.swift`, `Core/Persistence/MealPreferenceRepository.swift`, and matching tests.

**Figma references:** `SheetView(type: swap)`, Cart impact, `SheetView(type: budget)`, meal swap controls and leftover card. **Gate:** obtain before/after, exclusions, regeneration, over-budget reveal and no-option designs; resolve post-purchase editing policy.

**Interfaces:** `PlanChangeServiceProtocol.preview(_ change: PlanChange, in plan: WeeklyPlan) async throws -> PlanChangePreview`; `accept(_ preview: PlanChangePreview, expectedRevision: UUID) async throws -> WeeklyPlan`. Changes include targeted swap, regenerate day/week and new profile/budget. A preview contains proposed cart, total, allocation changes and constraint result.

- [ ] Test candidate filtering and complete-cart differences, then implement previews through the existing planner/calculator.
- [ ] Offer three to five safe replacements when available, with actual added/removed/reused packages, costs and reuse counts. Show fewer honestly when the catalog has fewer.
- [ ] Implement selected-meal targeting, exclusions, day/week regeneration and actionable leftover swaps.
- [ ] Add budget re-optimization with before/after accept/cancel; prevent stale preview acceptance and atomically persist plan/cart/profile changes.

**Definition of Done:** Every accepted change is feasible, preview matches committed outcome, all projections update together, and cancel/save failure leaves the old plan intact. Over-budget comparisons cannot silently become active plans.

**Verification:** Test a swap requiring an extra package despite lower ingredient consumption cost, last-use ingredient removal, allergy exclusion, blocked recipe persistence, infeasible budget reduction, unchanged non-target days, stale revision, cancellation and save rollback. UI test swap on a non-Wednesday meal and budget accept/cancel. Manually follow a forecast suggestion through its cart impact. Run full build/tests.

## Phase 7 — Shopping and actual spending

**Goal:** Track the real trip without hiding overspend or corrupting estimates.

**Scope / files:** Extend `Features/Groceries/`; add `Features/Shopping/`, `Core/Shopping/ShoppingService.swift`, trip/price-correction persistence and matching tests.

**Figma references:** `GroceryScreen(shopping: true)`, checked rows, live total and `SheetView(type: price)`. Preserve Make's tab structure. **Gate:** over-budget/substitute, incomplete-trip and spending-summary layouts must be supplied.

**Interfaces:** `ShoppingServiceProtocol.updatePrice(itemID: UUID, actualPrice: Money, tripID: UUID) async throws -> ShoppingTrip`; `finishTrip(_ tripID: UUID) async throws -> ShoppingSummary`. Actual prices remain distinct from versioned estimates, scoped to the relevant item/package/store.

- [ ] Define and test displayed actual-to-date versus projected-full-cart totals; unchecked items cannot disappear from forecast spending.
- [ ] Persist checkoff and actual-price edits for the tapped item, with decimal validation and interruption recovery.
- [ ] Warn on cap exceedance; preview catalog-backed cheaper substitutes through Phase 6 validation without changing allergens or required quantities.
- [ ] Finish the trip with honest missing-price/partial-purchase status; retain actual overspend as history and make approved corrections available to later plans.

**Definition of Done:** Price edits recalculate real totals, warnings are accurate, finishing does not fabricate receipts, and the trip survives relaunch. Purchased stock follows the agreed editing policy.

**Verification:** With a 6,430-cent estimate, changing an 896-cent item to 1,016 cents yields a 6,550-cent projected cart and 450 cents remaining under a 7,000-cent cap. Test over-cap corrections, negative/malformed prices, unchecking a priced item, partial trips, no valid substitute and duplicate finish. UI test shopping → correct a non-turkey item → finish → relaunch summary. Run full build/tests and manually verify estimates versus actual labels.

## Phase 8 — Today, cooking and skipped meals

**Goal:** Guide real cooking while preserving ingredients needed later.

**Scope / files:** `Features/Today/`, `Features/Cooking/`, `Core/Cooking/{CookingService,TimerService}.swift`, meal progress persistence and matching tests.

**Figma references:** `TodayScreen`, `CookMode`, `cookSteps`, ingredient/save notes. Replace sample instructions with reviewed recipes. **Gate:** timer UI, no-meal/completed states and skipped-meal suggestions need designs.

**Interfaces:** `CookingServiceProtocol.markCooked(mealID: UUID, planID: UUID) async throws`; `previewMove(mealID: UUID, to date: Date, planID: UUID) async throws -> PlanChangePreview`. Inject a clock/calendar for date-sensitive logic. Timer state uses a saved deadline rather than relying on foreground ticking.

- [ ] Test today's meal selection, ingredient reservations and idempotent completion before wiring cooking views.
- [ ] Show all today's meal slots and actual recipe steps, progress, optional timers, close/resume and use-now/save-later notes.
- [ ] Persist Mark as cooked exactly once; update allocations and history only on confirmed completion.
- [ ] Implement “I didn’t cook this” with rescheduling preview and ingredient-risk feedback; revalidate affected meals and stock before acceptance.

**Definition of Done:** Cooking follows the selected recipe, timers recover after backgrounding, completion survives relaunch, and skipped meals do not consume ingredients as if cooked.

**Verification:** Test midnight/time-zone boundaries, no scheduled meal, repeated completion, close/resume, expired/background timer, and a moved meal invalidating a later reservation. UI test Today → Cook → complete and Today → skip → preview/cancel. Manually check large text and VoiceOver throughout cooking; verify safe reviewed storage instructions. Run full build/tests.

## Phase 9 — Wrap-up, pantry and the next week

**Goal:** Complete the local weekly cycle with confirmed inventory and measurable savings.

**Scope / files:** `Features/WrapUp/`, `Features/Pantry/`, `Features/NextWeek/`, `Core/Persistence/{PantryRepository,HistoryRepository}.swift`, planner inventory input and matching tests.

**Figma references:** `PantryScreen`, savings banner, pantry rows/add affordance/Plan next week, setup summary. **Gate:** Week Wrap-Up, confirm-leftovers, pantry editor and next-week layouts are absent and must be supplied.

**Interfaces:** `PantryRepositoryProtocol.loadItems() async throws -> [PantryItem]`; `confirmCarryover(_ confirmation: CarryoverConfirmation) async throws`. Extend `PlanRequest` with confirmed available stock; store forecast, actual and confirmed leftovers separately.

- [ ] Test wrap-up totals and one-time carryover before implementing transactional confirmation.
- [ ] Display planned budget, recorded spending with completeness, cooked meals and user-confirmed remaining stock.
- [ ] Implement pantry add/edit/remove with normalized amounts and approved storage/expiry rules; never silently assume all forecast leftovers remain usable.
- [ ] Prefill next-week setup, reserve pantry once, and compute savings by costing the same proposed meals with and without available stock.

**Definition of Done:** A user can complete a week, confirm leftovers, edit pantry and generate a new feasible week using existing ingredients. History is immutable, stock cannot be spent twice, and savings reflect avoided package purchases.

**Verification:** Test duplicate carryover, partly consumed packages, removed/expired stock, user quantity corrections, pantry reservation rollback and zero savings when remaining stock still requires the same package count. UI test the complete two-week loop, including relaunch between wrap-up and planning. Manually reconcile stock and checkout cost. Run full build/tests.

## Phase 10 — Preferences, nutrition, optional sync and release readiness (MVP4 complete)

**Goal:** Finish the description's repeat-use features and verify a real distributable app.

**Scope / files:** `Features/Favorites/`, `Features/Ratings/`, `Features/Nutrition/`, `Features/Account/`; `Core/Services/{AccountService,SyncService}.swift`; extend preference/history repositories; provider-specific configuration only after selection; accessibility/privacy resources and integration/UI tests.

**Figma references:** Existing meal rows, settings sheet, pantry and save-note components form the established vocabulary. **Gate:** rating, favorites/pinning, nutrition, account and sync-state screen designs are missing. Provider, entitlements, account lifecycle and merge policy must be settled before dependent implementation.

**Interfaces:** `MealPreferenceRepositoryProtocol.rate(mealID: UUID, rating: MealRating) async throws`; favorites and exclusions share stable recipe IDs. Favorite pins enter `PlanRequest` as explicit constraints. `SyncServiceProtocol.synchronize() async throws -> SyncResult` consumes committed local records; provider-specific account operations follow the approved account contract.

- [ ] Test rating preference, favorite pin feasibility and vegetable/protein/whole-grain summary denominators; implement the reviewed feature screens.
- [ ] Add optional sign-in and synchronization for pantry, favorites and history; guests retain the complete local app. Store credentials in Keychain where applicable.
- [ ] Implement tested conflict/guest-merge, offline retry, sign-out and account deletion behavior; validate remote input and preserve local data on failures.
- [ ] Run the complete MVP1–MVP4 acceptance suite, privacy review, localization/accessibility pass, migration checks, on-device performance checks and archive validation.

**Definition of Done:** Ratings affect future preferences without weakening hard constraints; pinned favorites produce a feasible plan or a clear explanation. Nutrition uses simple balance indicators. Two devices can recover the same supported account data, and offline/guest use remains complete. The app archives with correct signing, privacy declarations and no placeholder feature actions. Missing designs/services prevent this phase being called complete.

**Verification:** Test a favorite that makes the cap impossible, exclusion versus pin conflict, correct nutrition counts across multiple meal slots, interrupted guest merge, duplicate upload, conflicting pantry edits, expired credentials, offline/reconnect, deletion and migration from previous schemas. Use a mocked transport/service for automated sync failures and two physical devices or separate test accounts for end-to-end sync. Run full build/tests and `xcodebuild -project MealWise.xcodeproj -scheme MealWise -destination 'generic/platform=iOS' archive` with configured signing; expect `ARCHIVE SUCCEEDED`. Manually complete setup → swap → shop → cook → wrap-up → next week without signing in or paying. Publishing is a separate user-authorized action.

## Scope boundaries and coverage

Phases 1–4 deliver MVP1; Phases 5–6 deliver MVP2; Phases 7–8 deliver shopping/cooking, with Wrap-Up completed in Phase 9; Phases 9–10 deliver MVP4. Every description MVP1–MVP4 feature has an owning phase, including optional accounts. Future PLUS, retailer comparison, advanced AI, SNAP eligibility and tips remain explicitly deferred as the description specifies; their screens and business decisions require a separate approved scope. Camera scanning, calorie/macro tracking, recipe import and household sharing are not part of this plan.

This is a planning artifact only. No app project, source implementation, dependency installation, account provisioning, or build verification was performed while preparing it.
