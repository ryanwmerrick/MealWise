import Combine
import Foundation

@MainActor
final class ExcludedRecipesViewModel: ObservableObject {
    @Published private(set) var ids: Set<String> = []
    @Published private(set) var errorMessage: String?
    private let preferences: any MealPreferenceRepositoryProtocol
    init(preferences: any MealPreferenceRepositoryProtocol) { self.preferences = preferences }
    func load() async {
        do { ids = try await preferences.loadExcludedRecipeIDs(); errorMessage = nil }
        catch { errorMessage = "Recipe preferences could not be loaded. Please retry." }
    }
    func allow(_ id: String) async {
        do { try await preferences.setExcluded(recipeID: id, excluded: false); await load() }
        catch { errorMessage = "The recipe preference could not be saved. Please retry." }
    }
}

struct RemainderSuggestion: Identifiable {
    let id: UUID
    let meal: ScheduledMeal
    let recipe: Recipe
    let preview: PlanChangePreview
}

@MainActor
final class RemainderSuggestionViewModel: ObservableObject {
    @Published private(set) var options: [RemainderSuggestion] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = true
    let plan: WeeklyPlan
    let ingredientID: String
    private let services: AppServices
    init(plan: WeeklyPlan, ingredientID: String, services: AppServices) {
        self.plan = plan; self.ingredientID = ingredientID; self.services = services
    }
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let excluded = try await services.preferences.loadExcludedRecipeIDs()
            var suggestions: [RemainderSuggestion] = []
            for meal in plan.meals {
                let candidates = plan.catalog.recipes.filter {
                    $0.id != meal.recipeID && !excluded.contains($0.id) && $0.ingredients.contains { $0.ingredientID == ingredientID } &&
                    PlanService.isEligible($0, slot: meal.slot, profile: plan.profile, catalog: plan.catalog)
                }
                for recipe in candidates {
                    try Task.checkCancellation()
                    let preview = try await services.changes.preview(.swap(mealID: meal.id, recipeID: recipe.id), in: plan)
                    if preview.constraint == .feasible,
                       let impact = preview.impacts.first(where: { $0.id == ingredientID }),
                       impact.newRequired > impact.oldRequired, impact.newPackages <= impact.oldPackages {
                        suggestions.append(RemainderSuggestion(id: UUID(), meal: meal, recipe: recipe, preview: preview))
                    }
                    if suggestions.count == 5 { break }
                }
                if suggestions.count == 5 { break }
            }
            options = suggestions; errorMessage = nil
        } catch is CancellationError { return }
        catch { errorMessage = "Remainder suggestions could not be loaded. Your current plan is unchanged." }
    }
}

