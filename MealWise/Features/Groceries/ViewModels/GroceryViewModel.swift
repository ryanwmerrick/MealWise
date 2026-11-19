import Combine
import Foundation

struct GroceryRow: Identifiable {
    let id: String
    let title: String
    let packages: Int64
    let packageSize: String
    let costMinorUnits: Int64
}

struct GrocerySection: Identifiable {
    let category: IngredientCategory
    let rows: [GroceryRow]
    var id: IngredientCategory { category }
}

@MainActor
final class GroceryViewModel: ObservableObject {
    @Published private var pricing: ShoppingCartSnapshot?
    @Published private(set) var errorMessage: String?

    private let planID: UUID
    private let shopping: any ShoppingServiceProtocol

    init(planID: UUID, shopping: any ShoppingServiceProtocol) {
        self.planID = planID
        self.shopping = shopping
    }

    func load() async {
        do {
            let snapshot = try await shopping.cart(planID: planID)
            try Task.checkCancellation()
            pricing = snapshot
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Your grocery list could not be loaded. Please retry."
        }
    }

    func hasActiveTrip(for plan: WeeklyPlan) -> Bool {
        snapshot(for: plan)?.isActive == true
    }

    func manualItems(for plan: WeeklyPlan) -> [ManualGroceryItem] {
        snapshot(for: plan)?.trip.addedItems ?? []
    }

    func addManualItem(name: String, quantity: String) async throws {
        pricing = try await shopping.addManualItem(name: name, quantity: quantity, planID: planID)
    }

    func removeManualItem(_ id: UUID) async {
        do {
            pricing = try await shopping.removeManualItem(id, planID: planID)
        } catch {
            errorMessage = "The item could not be removed. Please try again."
        }
    }

    func estimatedCost(for plan: WeeklyPlan) -> Int64 {
        (try? snapshot(for: plan)?.trip.projectedMinorUnits) ?? plan.totalMinorUnits
    }

    func sections(for plan: WeeklyPlan) -> [GrocerySection] {
        let prices = Dictionary(uniqueKeysWithValues: (snapshot(for: plan)?.trip.lines ?? []).compactMap { line in
            line.actualMinorUnits.map { (line.ingredientID, $0) }
        })
        var grouped: [IngredientCategory: [GroceryRow]] = [:]
        for item in plan.cart where item.packageCount > 0 {
            guard let ingredient = plan.catalog.ingredients.first(where: { $0.id == item.id }),
                  let offer = plan.catalog.offers.first(where: { $0.id == item.offerID }),
                  let size = try? Quantity(amount: offer.packageQuantity, unit: offer.unit) else { continue }
            let row = GroceryRow(id: item.id, title: ingredient.name, packages: item.packageCount,
                                 packageSize: size.display, costMinorUnits: prices[item.id] ?? item.costMinorUnits)
            grouped[ingredient.category ?? .other, default: []].append(row)
        }
        return IngredientCategory.allCases.compactMap { category in
            guard let rows = grouped[category] else { return nil }
            return GrocerySection(category: category, rows: rows.sorted { $0.title < $1.title })
        }
    }

    private func snapshot(for plan: WeeklyPlan) -> ShoppingCartSnapshot? {
        guard plan.closedAt == nil, pricing?.trip.planRevision == plan.revision else { return nil }
        return pricing
    }
}
