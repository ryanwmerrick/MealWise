import Combine
import Foundation

@MainActor final class FavoritesViewModel: ObservableObject {
    @Published private(set) var favorites: [Recipe] = []
    @Published private(set) var pins: [RecipePin] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    let catalog: RecipeCatalog
    let profile: PlanningProfile?
    private let repository: any MealPreferenceRepositoryProtocol
    init(catalog: RecipeCatalog, profile: PlanningProfile? = nil, repository: any MealPreferenceRepositoryProtocol) {
        self.catalog = catalog; self.profile = profile; self.repository = repository
    }
    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            let preferences = try await repository.loadRecipePreferences()
            favorites = catalog.recipes.filter { recipe in preferences.contains { $0.recipeID == recipe.id && $0.favorite } }
            pins = try await repository.loadPins(); errorMessage = nil
        } catch { errorMessage = "Your favorites could not be loaded. Please retry." }
    }
    func removeFavorite(_ recipe: Recipe) async {
        do { try await repository.setFavorite(recipeID: recipe.id, favorite: false); await load() }
        catch { errorMessage = "This favorite could not be updated. Please retry." }
    }
    func pin(recipeID: String, date: Date, slot: MealSlot) async -> Bool {
        do {
            guard let profile, profile.days.contains(date), profile.mealSlots.contains(slot), favorites.contains(where: { $0.id == recipeID }) else { throw PlanningError.invalidPlan }
            try await repository.savePin(RecipePin(recipeID: recipeID, date: date, slot: slot))
            await load()
            return true
        } catch { errorMessage = "This favorite could not be pinned. Review the selected date and meal slot."; return false }
    }
    func removePin(_ pin: RecipePin) async {
        do {
            try await repository.removePin(pin)
            await load()
        }
        catch { errorMessage = "This pin could not be removed. Please retry." }
    }
}
