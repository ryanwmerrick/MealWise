# Phase 10 local data review

The app starts in Welcome and uses a bundled development catalog. The Phase 10 paths use local SwiftData with CloudKit mirroring explicitly disabled. The store keeps plan and setup choices, grocery prices entered during shopping, cooking progress, ratings, favorites, pins, pantry and cycle history. Phase 10 introduces no network client, credentials, analytics, tracking or new permission prompts.

Start over clears the current plan and setup answers, releases pantry reservations and clears pending pins. Recorded history, pantry and preferences remain accessible. Confirming **Erase all local data** removes the MealWise records in the local store.

The current privacy manifest declares no tracking, collected data or required-reason APIs. Test-only store isolation is compiled into Debug builds. Production signing, physical-device accessibility and performance, launch content review and privacy declarations for any future connected build are release follow-up.
