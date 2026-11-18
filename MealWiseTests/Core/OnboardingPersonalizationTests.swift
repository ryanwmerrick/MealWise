import Foundation
import Testing
@testable import MealWise

struct OnboardingPersonalizationTests {
    @Test func preferencesRoundTripAndOldProfilesDecode() async throws {
        let old = await OnboardingViewModel.defaultProfile()
        let encoded = try JSONEncoder().encode(old)
        #expect(try JSONDecoder().decode(PlanningProfile.self, from: encoded).onboarding == nil)

        var updated = old
        updated.onboarding = OnboardingPreferences(goals: [.saveMoney], equipment: [.microwave], keto: true)
        let saved = try JSONEncoder().encode(updated)
        #expect(try JSONDecoder().decode(PlanningProfile.self, from: saved) == updated)
    }

    @Test func missingKitchenEquipmentExcludesRecipe() async throws {
        let catalog = try await CatalogService(allowDevelopment: true).loadCatalog()
        let recipe = try #require(catalog.recipes.first)
        let slot = try #require(recipe.mealSlots.first)
        var profile = await OnboardingViewModel.defaultProfile()
        profile.cookingTime = .flexible
        profile.skill = .experienced
        #expect(PlanService.isEligible(recipe, slot: slot, profile: profile, catalog: catalog))
        profile.onboarding = OnboardingPreferences(equipment: [.stove])
        #expect(PlanService.isEligible(recipe, slot: slot, profile: profile, catalog: catalog))
        profile.onboarding = OnboardingPreferences(equipment: [.microwave])
        #expect(!PlanService.isEligible(recipe, slot: slot, profile: profile, catalog: catalog))
    }
}
