# Phase 2 development catalog review

Status: **draft for review, not launch content**. User requested this development catalog on November 13, 2026. It contains synthetic package prices and authored, untested recipes. Nothing in this package claims retailer availability, supplier allergen certification, nutritional adequacy or cooking-test review.

**Development approval recorded:** The user approved the development-only policy and catalog in conversation on November 13, 2026. The original draft remains here for provenance; an approved development copy is bundled under `MealWise/Resources/Catalog/`. Its review status is `developmentApproved`, never `launchReviewed`; supplier allergen verification remains false.

## Proposed development policy

| Decision | Proposal |
| --- | --- |
| Currency / arithmetic | USD integer cents. Parse decimal text exactly; reject negative amounts, grouping/exponents and more than two fraction digits. Display using locale-aware currency formatting. |
| Cap | Sum whole purchased packages, including oil and seasonings used. No assumed free staples besides tap water. Tax/deposits/fees are excluded and clearly labeled; development offers have no such charges. Actual checkout prices remain estimates. |
| Cost labels | Checkout total uses package purchases. Recipe/serving consumption costs use package unit cost, with rounding only for display. These figures must not be summed to derive checkout totals. |
| Region/store | One synthetic “Development grocery” store with no location, ZIP search, distances or real retailer claim. All offers are dated 2026-11-13, with a proposed 30-day expiry and explicit synthetic provenance. Real launch regions/prices require replacement data. |
| Portions | Base recipe serves one adult portion. Ages 13+ count as 1; ages 2–12 as 0.5 adult portions. At least one adult, at most 12 people. Infants are outside scope and must not be included as covered by this planner. This scaling is a planning convention requiring product/content review, not nutrition advice. |
| Schedule | User chooses 1–7 actual calendar dates in one seven-day window, any nonempty combination of breakfast/lunch/dinner. Time is a strict maximum except explicit flexible selection. Beginner catalog; no special equipment beyond stove, saucepan, skillet, knife and board. |
| Allergens | Model the nine US major allergens. Ingredient allergen metadata must be explicitly verified before allergy-safe eligibility; unknown/unreviewed metadata is never safe. No claim about cross-contact from this draft. Supplier substitutions require revalidation. |
| Dietary support | Development recipes use plant ingredients; vegan, vegetarian and gluten-free filters may be exercised only against reviewed fixtures. Oats, tortillas and pasta need product-specific gluten/allergen review. Unsupported combinations must explain why a plan cannot be produced. |
| Quantities | Integer milligrams, milliliters or item counts as canonical units; exact mass conversions, no universal volume-to-mass conversion. Package weights must describe the same usable state as recipe requirements (e.g. drained beans). |
| Review | Recipe `reviewStatus` and ingredient `allergensVerified` remain draft/false. Automated schema validation cannot replace cooking tests or actual package-label/price review. Development prices are never promoted into regional launch estimates automatically. |

## Catalog contents

See [development-catalog.json](development-catalog.json) for quantities, numbered cooking instructions, simple vegetable/protein/whole-grain flags, and package offers. IDs are stable descriptive identifiers. Launch-mode catalog validation rejects the approved development copy.

| Meal slot | Recipes |
| --- | --- |
| Breakfast | Apple cinnamon oats; banana peanut oats; savory spinach oats; chickpea breakfast skillet |
| Lunch | Chickpea tortilla wraps; black bean rice bowl; tomato bean pasta; spinach chickpea couscous |
| Dinner | Black bean sweet potato skillet; chickpea tomato rice; spinach white bean pasta; bean pepper quesadillas |

## Review requested

Approve or adjust the development-only policy above and recipe/offer structure so Phase 2 can proceed against a clearly labeled synthetic catalog. Identify any recipe, allergen, portion or store changes you want before planner implementation. Actual launch review remains a separate prerequisite; approval of synthetic test inputs does not certify recipes, allergens or prices for real shopping.
