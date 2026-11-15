import Foundation
import SwiftData

protocol ShoppingServiceProtocol: Sendable {
    func openTrip(planID: UUID) async throws -> ShoppingTrip
    func updatePrice(itemID: UUID, actualPrice: Money, tripID: UUID) async throws -> ShoppingTrip
    func setChecked(itemID: UUID, checked: Bool, tripID: UUID) async throws -> ShoppingTrip
    func finishTrip(_ tripID: UUID) async throws -> ShoppingSummary
    func history(planID: UUID) async throws -> [ShoppingSummary]
    func cheaperSubstitutes(itemID: UUID, tripID: UUID) async throws -> [ShoppingSubstitutionPreview]
    func acceptSubstitute(_ option: ShoppingSubstitutionPreview) async throws -> ShoppingTrip
}

actor ShoppingService: ShoppingServiceProtocol {
    private let plans: PlanRepository
    init(plans: PlanRepository) { self.plans = plans }
    init(container: ModelContainer) { plans = PlanRepository(container: container) }
    func openTrip(planID: UUID) async throws -> ShoppingTrip { try await plans.openShoppingTrip(planID: planID) }
    func updatePrice(itemID: UUID, actualPrice: Money, tripID: UUID) async throws -> ShoppingTrip {
        try await plans.editShoppingTrip(tripID) { trip in
            guard let index = trip.lines.firstIndex(where: { $0.id == itemID }) else { throw ShoppingError.invalidItem }
            trip.lines[index].actualMinorUnits = actualPrice.minorUnits
        }
    }
    func setChecked(itemID: UUID, checked: Bool, tripID: UUID) async throws -> ShoppingTrip {
        try await plans.editShoppingTrip(tripID) { trip in
            guard let index = trip.lines.firstIndex(where: { $0.id == itemID }) else { throw ShoppingError.invalidItem }
            trip.lines[index].checked = checked
        }
    }
    func finishTrip(_ tripID: UUID) async throws -> ShoppingSummary { try await plans.finishShoppingTrip(tripID) }
    func history(planID: UUID) async throws -> [ShoppingSummary] { try await plans.shoppingHistory(planID: planID) }
    func cheaperSubstitutes(itemID: UUID, tripID: UUID) async throws -> [ShoppingSubstitutionPreview] {
        guard let plan = try await plans.loadActivePlan() else { throw ShoppingError.staleTrip }
        let trip = try await plans.openShoppingTrip(planID: plan.id)
        guard trip.id == tripID, let line = trip.lines.first(where: { $0.id == itemID }) else { throw ShoppingError.staleTrip }
        var options: [ShoppingSubstitutionPreview] = []
        for offer in plan.catalog.offers where offer.ingredientID == line.ingredientID && offer.storeID == trip.storeID && offer.id != line.offerID {
            try Task.checkCancellation()
            let preview = try await plans.previewShoppingOffer(plan: plan, ingredientID: line.ingredientID, offerID: offer.id)
            guard preview.constraint == .feasible, let proposed = preview.proposedPlan,
                  let item = proposed.cart.first(where: { $0.id == line.ingredientID }),
                  item.costMinorUnits < (line.actualMinorUnits ?? line.estimatedMinorUnits) else { continue }
            let projected = try trip.projectedMinorUnits - (line.actualMinorUnits ?? line.estimatedMinorUnits) + item.costMinorUnits
            guard projected <= trip.budgetMinorUnits else { continue }
            options.append(ShoppingSubstitutionPreview(id: UUID(), trip: trip, lineID: line.id, offer: offer,
                                                       preview: preview, projectedMinorUnits: projected))
        }
        return options.sorted { $0.projectedMinorUnits < $1.projectedMinorUnits }
    }
    func acceptSubstitute(_ option: ShoppingSubstitutionPreview) async throws -> ShoppingTrip {
        try await plans.acceptShoppingSubstitute(option)
    }

}

extension PlanRepository {
    // These operations run on the same actor as plan CAS, with no suspension inside each transaction.
    func openShoppingTrip(planID: UUID) throws -> ShoppingTrip {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let plan = try shoppingPlan(documents, id: planID)
        let key = "shopping-draft-" + planID.uuidString
        let document = documents.first { $0.key == key }
        let old = try document.map { try JSONDecoder().decode(ShoppingTrip.self, from: $0.payload) }
        if let old, old.planRevision == plan.revision { return old }
        let latest = try documents.filter { $0.key.hasPrefix("shopping-history-") }
            .map { try JSONDecoder().decode(ShoppingSummary.self, from: $0.payload) }
            .filter { $0.trip.planID == planID }
            .sorted { ($0.trip.finishedAt ?? .distantPast) > ($1.trip.finishedAt ?? .distantPast) }.first
        let lines = try plan.cart.filter { $0.packageCount > 0 }.map { item in
            guard let ingredient = plan.catalog.ingredients.first(where: { $0.id == item.id }),
                  let offer = plan.catalog.offers.first(where: { $0.id == item.offerID }) else { throw PlanningError.invalidPlan }
            let matches: (ShoppingLine) -> Bool = { $0.ingredientID == item.id && $0.offerID == item.offerID && $0.packageCount == item.packageCount }
            let previous = old?.lines.first(where: matches) ?? latest?.trip.lines.first { !$0.checked && matches($0) }
            return ShoppingLine(id: previous?.id ?? UUID(), ingredientID: item.id, offerID: item.offerID,
                                name: ingredient.name, packageCount: item.packageCount, packageQuantity: offer.packageQuantity,
                                unit: offer.unit, estimatedMinorUnits: item.costMinorUnits,
                                actualMinorUnits: previous?.actualMinorUnits, checked: previous?.checked ?? false)
        }
        let trip = ShoppingTrip(id: UUID(), planID: plan.id, planRevision: plan.revision, storeID: plan.profile.storeID,
                                budgetMinorUnits: plan.profile.budgetMinorUnits, priorSpendingMinorUnits: plan.resources?.committedMinorUnits ?? 0,
                                lines: lines, finishedAt: nil)
        try store(trip, key: key, documents: documents, context: context)
        try Task.checkCancellation(); try context.save()
        return trip
    }

    func editShoppingTrip(_ id: UUID, edit: @Sendable (inout ShoppingTrip) throws -> Void) throws -> ShoppingTrip {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let (document, original) = try draft(id, documents: documents)
        let plan = try shoppingPlan(documents, id: original.planID)
        guard original.planRevision == plan.revision else { throw ShoppingError.staleTrip }
        var trip = original
        try edit(&trip)
        _ = try trip.projectedMinorUnits
        document.payload = try JSONEncoder().encode(trip)
        try Task.checkCancellation(); try context.save()
        return trip
    }

    func finishShoppingTrip(_ id: UUID) throws -> ShoppingSummary {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let historyKey = "shopping-history-" + id.uuidString
        if let previous = documents.first(where: { $0.key == historyKey }) {
            return try JSONDecoder().decode(ShoppingSummary.self, from: previous.payload)
        }
        let (document, original) = try draft(id, documents: documents)
        let plan = try shoppingPlan(documents, id: original.planID)
        guard plan.revision == original.planRevision else { throw ShoppingError.staleTrip }
        guard original.lines.contains(where: \.checked) else { throw ShoppingError.noPurchases }
        var resources = plan.resources ?? PlanResources()
        for line in original.lines where line.checked {
            let quantity = line.packageCount.multipliedReportingOverflow(by: line.packageQuantity)
            guard !quantity.overflow else { throw PlanningError.overflow }
            resources.purchases.append(PurchasedStock(tripID: id, ingredientID: line.ingredientID, offerID: line.offerID,
                                                     quantity: quantity.partialValue, packageCount: line.packageCount,
                                                     actualMinorUnits: line.actualMinorUnits, estimatedMinorUnits: line.estimatedMinorUnits))
        }
        let priced = try CartCalculator.calculate(CartRequest(meals: plan.meals, profile: plan.profile, catalog: plan.catalog, resources: resources, offerOverrides: plan.offerOverrides))
        let updated = WeeklyPlan(id: plan.id, revision: UUID(), profile: plan.profile, catalog: plan.catalog,
                                 meals: plan.meals, cart: priced.items, totalMinorUnits: priced.totalMinorUnits, resources: resources, offerOverrides: plan.offerOverrides)
        try PlanValidation.validate(updated) // Real overspend is retained, rather than rejected or hidden.
        var trip = original; trip.finishedAt = .now
        let summary = ShoppingSummary(trip: trip)
        try store(updated, key: "activePlan", documents: documents, context: context)
        try store(summary, key: historyKey, documents: documents, context: context)
        context.delete(document)
        let checklistKey = "checklist-" + plan.id.uuidString
        if let checklist = documents.first(where: { $0.key == checklistKey }) {
            var checked = try JSONDecoder().decode(Set<String>.self, from: checklist.payload)
            checked.subtract(original.lines.filter(\.checked).map(\.ingredientID))
            checklist.payload = try JSONEncoder().encode(checked)
        }
        try Task.checkCancellation(); try context.save()
        return summary
    }

    func shoppingHistory(planID: UUID) throws -> [ShoppingSummary] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredDocument>()).filter { $0.key.hasPrefix("shopping-history-") }
            .map { try JSONDecoder().decode(ShoppingSummary.self, from: $0.payload) }.filter { $0.trip.planID == planID }
            .sorted { ($0.trip.finishedAt ?? .distantPast) > ($1.trip.finishedAt ?? .distantPast) }
    }

    private func shoppingPlan(_ documents: [StoredDocument], id: UUID) throws -> WeeklyPlan {
        guard let document = documents.first(where: { $0.key == "activePlan" }) else { throw ShoppingError.staleTrip }
        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: document.payload)
        guard plan.id == id else { throw ShoppingError.staleTrip }
        try PlanValidation.validate(plan)
        return plan
    }
    private func draft(_ id: UUID, documents: [StoredDocument]) throws -> (StoredDocument, ShoppingTrip) {
        for document in documents where document.key.hasPrefix("shopping-draft-") {
            let trip = try JSONDecoder().decode(ShoppingTrip.self, from: document.payload)
            if trip.id == id { return (document, trip) }
        }
        throw ShoppingError.missingTrip
    }
    private func store<T: Encodable>(_ value: T, key: String, documents: [StoredDocument], context: ModelContext) throws {
        let payload = try JSONEncoder().encode(value)
        if let document = documents.first(where: { $0.key == key }) { document.payload = payload }
        else { context.insert(StoredDocument(key: key, payload: payload)) }
    }
}

struct ShoppingSubstitutionPreview: Sendable, Identifiable {
    let id: UUID
    let trip: ShoppingTrip
    let lineID: UUID
    let offer: PackageOffer
    let preview: PlanChangePreview
    let projectedMinorUnits: Int64
}

extension PlanRepository {
    func previewShoppingOffer(plan: WeeklyPlan, ingredientID: String, offerID: String) async throws -> PlanChangePreview {
        let service = PlanChangeService(plans: self, planner: PlanService(), preferences: MealPreferenceRepository(container: container))
        return try await service.preview(.packageOffer(ingredientID: ingredientID, offerID: offerID), in: plan)
    }

    func acceptShoppingSubstitute(_ option: ShoppingSubstitutionPreview) throws -> ShoppingTrip {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let (document, trip) = try draft(option.trip.id, documents: documents)
        let current = try shoppingPlan(documents, id: trip.planID)
        guard trip == option.trip, current.revision == option.preview.baseRevision,
              trip.planRevision == current.revision else { throw ShoppingError.staleTrip }
        guard option.preview.constraint == .feasible, let proposed = option.preview.proposedPlan,
              proposed.id == current.id, proposed.meals == current.meals, proposed.profile == current.profile,
              proposed.catalog == current.catalog, proposed.resources == current.resources,
              proposed.totalMinorUnits <= proposed.profile.budgetMinorUnits,
              let index = trip.lines.firstIndex(where: { $0.id == option.lineID }),
              let item = proposed.cart.first(where: { $0.id == trip.lines[index].ingredientID }),
              item.offerID == option.offer.id, option.offer.ingredientID == item.id,
              option.offer.storeID == trip.storeID else { throw ShoppingError.invalidItem }
        try CatalogValidator.validate(proposed.catalog, allowDevelopment: true, now: .now)
        try PlanValidation.validate(proposed)
        var revised = trip
        let old = trip.lines[index]
        revised.lines[index] = ShoppingLine(id: UUID(), ingredientID: item.id, offerID: item.offerID, name: old.name,
                                           packageCount: item.packageCount, packageQuantity: option.offer.packageQuantity,
                                           unit: option.offer.unit, estimatedMinorUnits: item.costMinorUnits, actualMinorUnits: nil, checked: false)
        let projected = try revised.projectedMinorUnits
        guard projected == option.projectedMinorUnits, projected <= trip.budgetMinorUnits,
              item.costMinorUnits < (old.actualMinorUnits ?? old.estimatedMinorUnits) else { throw PlanChangeError.infeasible }
        revised = ShoppingTrip(id: revised.id, planID: revised.planID, planRevision: proposed.revision, storeID: revised.storeID,
                               budgetMinorUnits: revised.budgetMinorUnits, priorSpendingMinorUnits: revised.priorSpendingMinorUnits,
                               lines: revised.lines, finishedAt: nil)
        document.payload = try JSONEncoder().encode(revised)
        try store(proposed, key: "activePlan", documents: documents, context: context)
        try Task.checkCancellation(); try context.save()
        return revised
    }
}
