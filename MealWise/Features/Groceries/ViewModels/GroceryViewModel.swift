import Combine
import Foundation

struct GroceryRow: Identifiable {
    let id: String
    let title: String
    let packages: Int64
    let packageSize: String
    let cost: String
    let provenance: String
    let priceDate: String
}

struct GrocerySection: Identifiable {
    let category: IngredientCategory
    let rows: [GroceryRow]
    var id: IngredientCategory { category }
}

@MainActor
final class GroceryViewModel: ObservableObject {
    @Published private(set) var sections: [GrocerySection] = []
    @Published private(set) var checked: Set<String> = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false
    let plan: WeeklyPlan
    private let checklist: any ChecklistRepositoryProtocol

    init(plan: WeeklyPlan, checklist: any ChecklistRepositoryProtocol) { self.plan = plan; self.checklist = checklist }

    func load() async {
        do {
            var grouped: [IngredientCategory: [GroceryRow]] = [:]
            for item in plan.cart {
                guard let ingredient = plan.catalog.ingredients.first(where: { $0.id == item.ingredientID }),
                      let offer = plan.catalog.offers.first(where: { $0.id == item.offerID }) else { throw PlanningError.invalidPlan }
                let size = try Quantity(amount: offer.packageQuantity, unit: offer.unit)
                let row = GroceryRow(id: item.id, title: ingredient.name, packages: item.packageCount,
                                     packageSize: size.display, cost: item.costMinorUnits.currency,
                                     provenance: offer.provenance, priceDate: offer.priceDate)
                grouped[ingredient.category ?? .other, default: []].append(row)
            }
            let checked = try await checklist.load(planID: plan.id)
            try Task.checkCancellation()
            sections = IngredientCategory.allCases.compactMap { category in
                guard let rows = grouped[category], !rows.isEmpty else { return nil }
                return GrocerySection(category: category, rows: rows.sorted { $0.title < $1.title })
            }
            self.checked = checked.intersection(Set(plan.cart.map(\.id)))
            errorMessage = nil
        } catch is CancellationError { return }
        catch { errorMessage = "Your grocery list could not be loaded. Please retry." }
    }

    func toggle(_ id: String) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await checklist.toggle(itemID: id, plan: plan)
            checked = try await checklist.load(planID: plan.id).intersection(Set(plan.cart.map(\.id)))
            errorMessage = nil
        } catch is CancellationError { return }
        catch { errorMessage = "Your checklist change could not be saved. Please retry." }
    }
}
