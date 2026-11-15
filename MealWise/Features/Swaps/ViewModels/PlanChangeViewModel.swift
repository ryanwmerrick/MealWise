import Combine
import Foundation

@MainActor
final class PlanChangeViewModel: ObservableObject {
    @Published var budgetText: String {
        didSet { if oldValue != budgetText { preview = nil; requestID = UUID() } }
    }
    @Published private(set) var preview: PlanChangePreview?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWorking = false
    let plan: WeeklyPlan
    private let changes: any PlanChangeServiceProtocol
    private var requestID = UUID()

    init(plan: WeeklyPlan, changes: any PlanChangeServiceProtocol) {
        self.plan = plan; self.changes = changes
        self.budgetText = NSDecimalNumber(decimal: Decimal(plan.profile.budgetMinorUnits) / 100).stringValue
    }

    func prepare(_ change: PlanChange) async {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil; preview = nil
        let request = UUID()
        requestID = request
        defer { isWorking = false }
        do {
            let proposed = try await changes.preview(change, in: plan)
            guard requestID == request, !Task.isCancelled else { return }
            preview = proposed
        }
        catch is CancellationError { return }
        catch CatalogError.expiredPrices {
            if requestID == request { errorMessage = "Prices have expired. Updated estimates are needed before changing this plan." }
        }
        catch {
            if requestID == request { errorMessage = "This change could not be previewed. Your current plan is unchanged. Please retry." }
        }
    }

    func prepareBudget() async {
        do {
            var profile = plan.profile
            profile.budgetMinorUnits = try Money.parse(budgetText).minorUnits
            try profile.validate()
            await prepare(.profile(profile))
        } catch { errorMessage = "Enter a positive dollar amount with at most two decimal places."; preview = nil }
    }

    func accept() async -> WeeklyPlan? {
        guard let preview, !isWorking else { return nil }
        isWorking = true
        defer { isWorking = false }
        do { return try await changes.accept(preview, expectedRevision: plan.revision) }
        catch is CancellationError { return nil }
        catch PlanChangeError.stalePreview { errorMessage = "This preview is out of date. Reopen it from your current week."; return nil }
        catch { errorMessage = "The change could not be saved. Your current plan is unchanged. Please retry."; return nil }
    }
}

struct SwapOption: Identifiable {
    let recipe: Recipe
    let preview: PlanChangePreview
    var id: String { recipe.id }
}

@MainActor
final class SwapViewModel: ObservableObject {
    @Published var showOverBudget = false
    @Published var selectedID: String?
    @Published private(set) var options: [SwapOption] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var notice: String?
    @Published private(set) var isWorking = false
    let plan: WeeklyPlan
    let mealID: UUID
    private let services: AppServices

    init(plan: WeeklyPlan, mealID: UUID, services: AppServices) {
        self.plan = plan; self.mealID = mealID; self.services = services
    }

    var target: ScheduledMeal? { plan.meals.first { $0.id == mealID } }
    var visibleOptions: [SwapOption] {
        let feasible = Array(options.filter { $0.preview.constraint == .feasible }.prefix(5))
        return showOverBudget ? feasible + Array(options.filter { $0.preview.constraint == .overBudget }.prefix(5)) : feasible
    }
    var selected: SwapOption? { visibleOptions.first { $0.id == selectedID } }

    func load() async {
        guard let target else { errorMessage = "This meal is no longer in your current plan."; return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let excluded = try await services.preferences.loadExcludedRecipeIDs()
            let recipes = plan.catalog.recipes.filter {
                $0.id != target.recipeID && !excluded.contains($0.id) &&
                PlanService.isEligible($0, slot: target.slot, profile: plan.profile, catalog: plan.catalog)
            }.sorted { $0.id < $1.id }
            var options: [SwapOption] = []
            for recipe in recipes {
                try Task.checkCancellation()
                let preview = try await services.changes.preview(.swap(mealID: mealID, recipeID: recipe.id), in: plan)
                options.append(SwapOption(recipe: recipe, preview: preview))
            }
            self.options = options
            selectedID = options.first { $0.preview.constraint == .feasible }?.id
        } catch is CancellationError { return }
        catch CatalogError.expiredPrices { errorMessage = "Prices have expired. Updated estimates are needed before changing this plan." }
        catch { errorMessage = "Replacement meals could not be loaded. Your current plan is unchanged." }
    }

    func excludeCurrent() async {
        guard let target else { return }
        do {
            try await services.preferences.setExcluded(recipeID: target.recipeID, excluded: true)
            notice = "This recipe is excluded from future choices. Your current plan changes only after you accept a preview."
        } catch { errorMessage = "The recipe preference could not be saved. Please retry." }
    }

    func accept() async -> WeeklyPlan? {
        guard let selected, selected.preview.constraint == .feasible, !isWorking else { return nil }
        isWorking = true
        defer { isWorking = false }
        do { return try await services.changes.accept(selected.preview, expectedRevision: plan.revision) }
        catch is CancellationError { return nil }
        catch PlanChangeError.stalePreview { errorMessage = "This preview is out of date. Reopen it from your current week."; return nil }
        catch { errorMessage = "The swap could not be saved. Your current plan is unchanged. Please retry."; return nil }
    }
}
