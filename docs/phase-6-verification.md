# Phase 6 — safe plan changes

Selected-meal swaps, day/week regeneration, recipe exclusions, remainder suggestions, and budget/profile changes use one preview/accept service. Every preview shows the complete proposed cart, package additions/removals/reuse, quantities, costs, budget result, and proposed schedule. Over-budget comparisons cannot be accepted. No-result states retain the current plan.

Acceptance revalidates food constraints, price dates, exclusions and the expected revision. Plan, profile and changed grocery reminders commit in a single SwiftData transaction. Cancellation, invalid data and stale revisions preserve the current plan. Exclusions persist independently and affect future choices without silently changing existing meals.

The reviewer found that diversity ranking could suppress a valid targeted day change when all dinner recipes already appeared in a week. A four-day regression failed before the fix; ranking now prioritizes changing the targeted recipes before diversity. A delayed-preview test also reproduced a budget edit race: obsolete search results are now discarded. Candidate pricing considers all eligible recipes before selecting the visible feasible options.

Unit result `/private/tmp/mealwise-phase6-core-complete.xcresult`: Passed, 59 tests, zero failures. Coverage includes whole-package checkout versus consumption cost, last-use removal, hard food constraints, persisted exclusions, infeasible budgets, unchanged other days, stale revisions, cancellation, invalid-save rollback, and delayed results. Existing planner tests exercise allergy filtering against verified ingredient metadata; the development catalog remains unsuitable for allergy-sensitive launch use.

The focused swap/budget UI flow passed at `/private/tmp/mealwise-phase6-swap-ui.xcresult`: select the first scheduled meal, accept its replacement, cancel a budget preview, then accept a different budget. Full integration verification is pending below.

Purchased stock and cooked history are introduced in Phases 7–8, where the approved remaining-cycle rules must be integrated. Phase 6 operates on an unpurchased, uncooked plan; it does not claim historical accounting is already implemented.

Full build/test `/private/tmp/mealwise-phase6-final.xcresult`: Passed, 67 tests (59 unit + eight UI), zero failures. The previously recorded unsourced frame warning remains in two UI transitions. Added focused forecast navigation `/private/tmp/mealwise-phase6-forecast.xcresult`: Passed, one UI test, no runtime warnings. Exported dark-mode preview was inspected: onion planned use increases from 300 g to 320 g with one package unchanged; corn tortillas drop from one package to zero, checkout falls from $26.32 to $24.83, and the $70 cap leaves $45.17. Cancel returns to the suggestions without committing.
