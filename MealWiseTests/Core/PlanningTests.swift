import Foundation
import Testing
@testable import MealWise

struct PlanningTests {
    @Test func equalCostPlansPreferLessUnusedPackageValue() async throws {
        let original = try await catalog()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        let recipes = try #require(json["recipes"] as? [[String: Any]])
        var lowUse = try #require(recipes.first { $0["id"] as? String == "chickpea-rice" })
        lowUse["id"] = "a-low-use"
        lowUse["ingredients"] = [["ingredientID": "chickpeas", "quantity": 10000, "unit": "milligrams"]]
        var highUse = lowUse
        highUse["id"] = "b-high-use"
        highUse["ingredients"] = [["ingredientID": "chickpeas", "quantity": 200000, "unit": "milligrams"]]
        json["recipes"] = [lowUse, highUse]
        let synthetic = try JSONDecoder().decode(RecipeCatalog.self, from: JSONSerialization.data(withJSONObject: json))
        var profile = PlanningProfile.fixture
        profile.children = 0
        let result = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: profile, catalog: synthetic))
        guard case .feasible(let plan) = result else { Issue.record("Expected reuse fixture"); return }
        #expect(plan.meals.first?.recipeID == "b-high-use")
    }

    @Test func syntheticCheckoutLeavesFiveSeventy() async throws {
        let original = try await catalog()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        let recipes = try #require(json["recipes"] as? [[String: Any]])
        json["recipes"] = [try #require(recipes.first { $0["id"] as? String == "chickpea-rice" })]
        var offers = try #require(json["offers"] as? [[String: Any]])
        for index in offers.indices {
            offers[index]["priceMinorUnits"] = offers[index]["ingredientID"] as? String == "chickpeas" ? 6030 : 100
        }
        json["offers"] = offers
        let synthetic = try JSONDecoder().decode(RecipeCatalog.self, from: JSONSerialization.data(withJSONObject: json))
        var profile = PlanningProfile.fixture
        profile.children = 0
        let result = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: profile, catalog: synthetic))
        guard case .feasible(let plan) = result else { Issue.record("Expected synthetic budget plan"); return }
        #expect(plan.totalMinorUnits == 6430)
        #expect(plan.remainingMinorUnits == 570)
    }

    @Test func glutenFreeRequiresExplicitRecipeEligibility() async throws {
        let original = try await catalog()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var ingredients = try #require(json["ingredients"] as? [[String: Any]])
        for index in ingredients.indices { ingredients[index]["allergensVerified"] = true }
        json["ingredients"] = ingredients
        let verified = try JSONDecoder().decode(RecipeCatalog.self, from: JSONSerialization.data(withJSONObject: json))
        var profile = PlanningProfile.fixture
        profile.preferences = [.glutenFree]
        let outcome = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: profile, catalog: verified))
        guard case .noFeasiblePlan = outcome else { Issue.record("Missing gluten-free recipe eligibility must fail closed"); return }
    }

    private func catalog() async throws -> RecipeCatalog {
        try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
    }

    @Test func exactCapAcceptedAndOneCentUnderRejected() async throws {
        let catalog = try await catalog()
        var profile = PlanningProfile.fixture
        profile.adults = 1; profile.children = 0
        let service = PlanService(clock: { Date(timeIntervalSince1970: 1794528000) })
        let initial = try await service.generate(PlanRequest(profile: profile, catalog: catalog))
        guard case .feasible(let plan) = initial else { Issue.record("Expected feasible plan"); return }
        profile.budgetMinorUnits = plan.totalMinorUnits
        let exact = try await service.generate(PlanRequest(profile: profile, catalog: catalog))
        guard case .feasible(let capped) = exact else { Issue.record("Exact cap must pass"); return }
        #expect(capped.totalMinorUnits == profile.budgetMinorUnits)
        profile.budgetMinorUnits -= 1
        let over = try await service.generate(PlanRequest(profile: profile, catalog: catalog))
        guard case .noFeasiblePlan = over else { Issue.record("One-cent-over cart must fail"); return }
    }

    @Test func requestedSlotsAndHouseholdAreCovered() async throws {
        var profile = PlanningProfile.fixture
        profile.mealSlots = [.breakfast, .lunch, .dinner]
        let outcome = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: profile, catalog: catalog()))
        guard case .feasible(let plan) = outcome else { Issue.record("Expected feasible slots"); return }
        #expect(plan.meals.count == 3)
        #expect(Set(plan.meals.map(\.slot)) == [.breakfast, .lunch, .dinner])
        #expect(plan.profile.adultHalfPortions == 4)
    }

    @Test func unknownAllergensFilterAllRecipes() async throws {
        var profile = PlanningProfile.fixture
        profile.allergies = [.peanut]
        let outcome = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: profile, catalog: catalog()))
        guard case .noFeasiblePlan = outcome else { Issue.record("Unknown allergen metadata must be excluded"); return }
    }

    @Test func boundedSearchIsNotFalseInfeasibility() async throws {
        let outcome = try await PlanService(nodeLimit: 0, clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: .fixture, catalog: catalog()))
        guard case .searchLimit = outcome else { Issue.record("Must report search limit"); return }
    }

    @Test func sharedRequirementsAreRoundedAfterAggregation() async throws {
        let catalog = try await catalog()
        let recipe = try #require(catalog.recipes.first { $0.id == "chickpea-rice" })
        let profile = PlanningProfile.fixture
        let meals = [ScheduledMeal(id: UUID(), date: profile.days[0], slot: .dinner, recipeID: recipe.id), ScheduledMeal(id: UUID(), date: profile.days[0], slot: .lunch, recipeID: recipe.id)]
        let cart = try CartCalculator.calculate(meals: meals, profile: profile, catalog: catalog)
        let rice = try #require(cart.first { $0.ingredientID == "quick-brown-rice" })
        #expect(rice.requiredQuantity == 280000)
        #expect(rice.packageCount == 1)
        #expect(rice.costMinorUnits == 249)
    }

    @Test func planPersistsAndRestores() async throws {
        let outcome = try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: .fixture, catalog: catalog()))
        guard case .feasible(let plan) = outcome else { Issue.record("Expected plan"); return }
        let container = try await LocalStore.makeContainer(inMemory: true)
        let repository = PlanRepository(container: container)
        try await repository.saveActivePlan(plan)
        #expect(try await repository.loadActivePlan() == plan)
        #expect(try await ProfileRepository(container: container).loadProfile() == plan.profile)
    }

    @Test func cancellationDoesNotReturnPartialPlan() async throws {
        let catalog = try await catalog()
        let task = Task {
            try Task.checkCancellation()
            return try await PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }).generate(PlanRequest(profile: .fixture, catalog: catalog))
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
