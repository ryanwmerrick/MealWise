# Phase 5 — ingredient accountability

The allocation service validates the committed snapshot, checks overflow, allocates normalized quantities in date/meal-slot order, and verifies purchased = allocated + remaining for every cart item. Report totals never assume a partly used package is fully consumed.

Week links to a complete Ingredient Map and an actual leftover forecast. Map details show purchased/allocated/remaining amounts and each dated meal's quantity, then open that meal's recipe. Recipe notes reserve exact quantities for later meals, including breakfast/lunch/dinner ordering on the same date. All plan navigation uses one typed route; mixing direct pushes with value destinations was caught by the map-to-recipe UI test and removed.

Storage classification is optional, approved development metadata. Fresh, opened-can, frozen or unknown storage remainders need attention. Shelf-stable items are conditional carryover; no automatic shelf-life duration or safety guarantee is invented. Forecast amounts remain distinct from confirmed pantry inventory, which is Phase 9. Legacy snapshots without storage metadata load conservatively rather than claiming safe carryover.

Tests cover conservation, multi-package beans, shelf-stable pasta, changed input order, later-meal reservations and same-day meal-slot ordering. Legacy metadata decoding and note text contrast are also checked. UI covers Week → Map → Ingredient → Recipe. Independent review found no important allocation issues and requested localization completion/same-day coverage; both were added. A nullable forecast count surfaces errors as unavailable rather than falsely showing zero items needing attention.

Manual arithmetic: four 240 g bean cans provide 960 g; three 300 g meal allocations use 900 g; 60 g remains and needs a storage check. A single-meal 450 g pasta package with 160 g allocated leaves 290 g conditional shelf-stable carryover. The report stores no assumed expiry date.

Full build/test result `/private/tmp/mealwise-phase5-verified.xcresult`: Passed, 54 tests total (47 unit, seven UI), zero failures. The dark-mode map screenshot was exported and inspected; bean package totals and remainder reconcile as above. Quiet Xcode commands use structured result summaries as evidence instead of redirected console markers.

Integration also exposed a stale dismissal after reset that could pop newly reopened setup. Reset/accept now let the root session transition remove the obsolete presentation, and the UI helper waits for confirmation to disappear. The full suite verifies the sequence across multiple flows. Xcode reported a frame warning in the keyboard/reentry case with no source location; Welcome's negative illustration padding was replaced with equivalent positive layout and is being checked with that focused regression.

Focused keyboard/reentry verification `/private/tmp/mealwise-phase5-layout.xcresult` passes after the positive-layout change. The same unsourced frame warning remains; no clipped content or failed interaction was observed. It is an unresolved release diagnostic, not reported as fixed. Allocation checks have no arithmetic/concurrency errors.
