# Phase 4 — consolidated groceries and usable recipes

Implemented categorized grocery rows from the committed cart, whole-package counts/sizes, checkout totals, dated synthetic-price metadata, and a persisted checklist. Checks are reminders, not purchases; actual receipts/prices remain Phase 7. No account or network access is required.

Every Week meal now opens its own persisted plan/meal ID in a native recipe detail. Detail shows scaled household ingredient quantities, consumption cost/per adult-equivalent serving, real recipe time/skill, numbered catalog steps, simple nutrition flags and links to other meals sharing ingredients. The missing screen layout was authored under the user's approval using the existing cards, green palette and native lists/navigation.

`CartRequest` / `PricedCart` use the same package calculator as generation. `PlanCostBreakdown` supplies both Week and Recipe consumption costs so rounded ingredient allocations cannot drift between screens. Ingredient categories are optional in saved catalogs; old snapshots restore into an honest Other section rather than being discarded or mislabeled.

Verification covers checklist restore/invalid IDs, household recipe scaling, no assumed free staples, cart/plan reconciliation, stable-ID detail lookup and pre-category snapshot restore. UI opens all five planned meals, checks an item and verifies it after relaunch. Screenshots are retained for visual review.

Hand reconciliation for one adult and two half-portioned children, spinach white bean pasta: 300 g drained beans need two 240 g cans (178 cents); 160 g dry pasta needs one 450 g package (149 cents); 200 g spinach needs one 300 g bag (129 cents); 10 mL oil needs one 500 mL bottle (299 cents). Whole-package checkout is 755 cents; consumed ingredients total approximately 256.21 cents, displayed as $2.56, or $1.28 per adult-equivalent portion. Instructions boil the measured pasta, heat the measured spinach/beans with oil, then combine. This is a quantity/instruction walkthrough, not a claim of physical cooking-test certification.

The development notice remains visible. Recipe testing, actual supplier allergens and real regional prices remain launch prerequisites. Independent review found no critical/important issues and requested the explicit older-snapshot regression, which was added. Final full build/test and visual results are recorded before committing.

Integration caught a budget-card accessibility regression once recipe links were added: a nested progress element confused the card's accessible control role. The redundant progress node is hidden from accessibility, and the parent exposes one explicit button with a combined monetary label. The regression test now actually opens Budget Details after scrolling instead of relying only on a hittability property. Exported recipe/grocery screenshots were inspected on the smaller dark-mode simulator; quantities, package counts, selected checkmarks and native text remain legible.

Final `/private/tmp/mealwise-phase4-verified.log`: `BUILD SUCCEEDED`, `TEST SUCCEEDED`, 42 Swift Testing tests and six UI tests, zero failures. Result bundle: `/private/tmp/mealwise-phase4-verified.xcresult`.
