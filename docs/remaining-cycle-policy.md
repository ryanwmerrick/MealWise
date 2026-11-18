# Proposed remaining-cycle rules

These choices resolve the business-rule gates in `implementation.md` for Phases 5–9. They do not change the approved development-only status of recipes or prices.

Approved by the user in conversation on November 14, 2026.

1. **Purchased and cooked history:** Never rewrite a finished trip, its actual spending, purchased quantities, or a cooked meal. Regeneration, settings and swaps preview changes to remaining uncooked meals. Purchased stock stays available to those meals; it is not bought or counted twice. Additional purchases must fit the remaining budget. An actual overspend stays visible as history and cannot be erased by swapping a meal.
2. **Over-budget comparisons:** Users may reveal an over-budget swap for comparison. Its confirmation stays disabled until an explicit budget change yields a feasible estimate. Every accepted change revalidates the active revision and commits the meal/cart/allocation changes together.
3. **Forecast uncertainty:** “At risk” means a perishable remainder needs attention, based on planned use and storage metadata; it is never a guarantee of spoilage or safety. Without verified storage/expiry data, display uncertainty and direct users to the package instructions. Do not invent shelf-life durations.
4. **Carryover:** Forecast leftovers are not inventory. At wrap-up, the user confirms remaining quantities, storage and any label/use-by date. Only user-confirmed available stock enters the next plan; expired stock is excluded. Unknown expiry is labeled, and availability requires explicit user confirmation. Removing or editing stock invalidates stale previews and reservations. Savings compare the same meals with and without confirmed stock, using whole-package purchases.
5. **Cooking and skipped meals:** Only confirmed completion consumes ingredient allocations, once. Skipped meals consume nothing; moving them previews reservation and risk changes before acceptance. Timer deadlines survive backgrounding without requesting notification permission.

Recipe safety and actual storage handling remain outside a synthetic development dataset; these rules describe the app's accounting and honesty about uncertainty.
