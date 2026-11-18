import Foundation
import SwiftData

extension PlanRepository {
    /// Reconcile current remaining requirements, without changing recorded stock or closed history.
    func reconcileExpiredPantry(at now: Date) throws {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        guard let document = documents.first(where: { $0.key == "activePlan" }) else { return }
        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: document.payload)
        guard plan.closedAt == nil, let resources = plan.resources,
              resources.pantryCredits?.contains(where: { $0.remainingQuantity > 0 }) == true else { return }
        try PlanValidation.validate(plan)
        let priced = try CartCalculator.calculate(CartRequest(meals: plan.meals, profile: plan.profile, catalog: plan.catalog,
            resources: resources, offerOverrides: plan.offerOverrides, pricedAt: now))
        guard priced.items != plan.cart || priced.totalMinorUnits != plan.totalMinorUnits else { return }
        let updated = try repricedPlan(plan, resources: resources, at: now)
        document.payload = try JSONEncoder().encode(updated)
        if let checklist = documents.first(where: { $0.key == "checklist-" + plan.id.uuidString }) {
            var checked = try JSONDecoder().decode(Set<String>.self, from: checklist.payload)
            let changed = Set(updated.cart.filter { item in
                guard let previous = plan.cart.first(where: { $0.id == item.id }) else { return true }
                return previous.packageCount != item.packageCount || previous.offerID != item.offerID
            }.map(\.id))
            checked.subtract(changed)
            checklist.payload = try JSONEncoder().encode(checked)
        }
        try savePantryContext(context)
    }
}
