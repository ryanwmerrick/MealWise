# Phase 10 verification

The revised Phase 10 ships a local simulator demo. The app opens to Welcome and uses bundled sample recipes and synthetic grocery prices. Local SwiftData supports relaunch, saved preferences, archived cycles and a confirmed erase action. See the [walkthrough](presentation-guide.md) and [local data review](privacy-review.md).

- The baseline UI regression reached Plan settings and failed because Favorites was absent. The targeted iPhone 17 run passed 95 unit tests and three UI tests, including Favorites and nutrition navigation and erasing saved setup across relaunch.
- Unit coverage includes ratings under hard food constraints, pins that conflict with exclusions or exceed the budget, rejection of a stale pin preview, atomic pin consumption, repeated meal slots in nutrition counts, older stored plans and exclusions, and expiry-driven pantry repricing.
- The focused iPhone 17e two-week run passed. It cooked and rated a meal, confirmed carryover, relaunched, pinned the saved recipe into the first next-week slot, accepted the plan, and opened the previous receipt. The inspected preview applied 420 g of confirmed black beans and showed $1.78 in estimated package savings.
- On iPhone 17e in dark mode, the largest accessibility text size passed contrast, hit-region, Dynamic Type and clipping audits for Favorites and Weekly nutrition. Inspected screenshots confirmed both titles are visible.
- Peer review identified that periodic refresh could close open shopping screens when a purchase changed the plan revision. Reconciliation runs at the established read and shopping boundaries. The next-week review also offers direct access to pins for the current draft schedule.
- The unsigned iOS Release archive succeeded. The archived app contains the bundled fixture catalog, compiled app icons, English strings and privacy manifest. Code signing and physical-device checks are reserved for distribution.

All 95 unit tests and all 19 UI scenarios passed across the simulator runs. The parallel attempt produced timeouts and exposed selectors that ran before their controls were ready. Serial and focused runs verified the five affected scenarios. The earlier unsourced SwiftUI frame warnings can still occur. The clean iPhone 17e dark-mode audits and two-week run did not report those warnings.
