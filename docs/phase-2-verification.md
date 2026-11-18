# Phase 2 — development data, arithmetic and persistence

The user approved the development-only catalog and accounting/portion/store policy in `catalog-review/README.md`. This explicitly replaces the reviewed-launch-data gate **for development testing only**. The catalog is not launch-reviewed and all supplier allergen verification flags remain false. Launch-mode validation rejects it; constrained allergy eligibility never treats unknown metadata as safe.

Implemented:

- USD integer cents, exact decimal parsing, checked arithmetic and validated Codable decoding.
- Explicit normalized mass/volume/count quantities; incompatible conversions rejected; package ceilings computed with quotient/remainder, avoiding addition overflow.
- Profile validation for approved household bounds, selected dates/slots and synthetic store.
- Stable-ID catalog with 12 recipes, 19 ingredients/offers, provenance, price dates and expiry. Every load reevaluates the clock. Invalid IDs, requirements, units, instructions and incomplete textual metadata are rejected.
- Versioned SwiftData schema, actor-isolated profile repository, transactional save/rollback, typed open/read/decode/save failures. Initializers do no disk work.

Tests cover the plan's six named cases plus malformed/overflow/decoded inputs, duplicate dates, catalog IDs, expired prices, expiry across repeated loads, incomplete recipes, corrupt persisted payloads, rejected saves preserving prior data, actual SQLite reopen and actual invalid-store-location failure. Failure-case tests intentionally provoke Core Data diagnostic logging; a handled storage failure is not counted as a failing test.

Evidence: the negative-decoding tests first reproduced unsafe synthesized Codable acceptance; explicit decoders fix it. Whitespace-title/equipment tests first failed and pass after required-text validation. Disk tests use temporary SQLite stores, leaving the app's store untouched.

Independent review found the frozen validation-clock issue and incomplete text validation; both are addressed with regression coverage. Final full `xcodebuild ... build test` on iPhone 17e / iOS 27 reports `BUILD SUCCEEDED`, `TEST SUCCEEDED`: 22 Swift Testing tests and three UI tests, zero failures. Log: `/private/tmp/mealwise-phase2-verified.log`.

Limits: The catalog is English development content with synthetic prices, not observed retailer pricing. Physically cooking and reviewing recipes and supplier labels remains launch work. There is no planning UI until Phase 3; profile persistence is verified directly, including reopening SQLite, rather than claiming an unavailable UI relaunch flow.
