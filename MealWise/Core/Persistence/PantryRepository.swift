import CryptoKit
import Foundation
import SwiftData

protocol PantryRepositoryProtocol: Sendable {
    func loadItems() async throws -> [PantryItem]
    func save(_ item: PantryItem, expectedRevision: UUID?) async throws
    func remove(id: UUID, expectedRevision: UUID) async throws
    func confirmCarryover(_ confirmation: CarryoverConfirmation) async throws
}

actor PantryRepository: PantryRepositoryProtocol {
    private let plans: PlanRepository
    private let catalog: RecipeCatalog
    private let clock: @Sendable () -> Date
    init(plans: PlanRepository, catalog: RecipeCatalog, clock: @escaping @Sendable () -> Date = { .now }) {
        self.plans = plans; self.catalog = catalog; self.clock = clock
    }
    func loadItems() async throws -> [PantryItem] { try await plans.pantryItems(catalog: catalog) }
    func save(_ item: PantryItem, expectedRevision: UUID?) async throws { try await plans.writePantry(item, expectedRevision: expectedRevision, catalog: catalog, at: clock()) }
    func remove(id: UUID, expectedRevision: UUID) async throws { try await plans.removePantry(id: id, expectedRevision: expectedRevision, catalog: catalog, at: clock()) }
    func confirmCarryover(_ confirmation: CarryoverConfirmation) async throws { try await plans.closeCycle(confirmation, at: clock()) }
}

extension PlanRepository {
    func pantryItems(catalog: RecipeCatalog) throws -> [PantryItem] {
        let context = ModelContext(container)
        do {
            let items = try context.fetch(FetchDescriptor<StoredDocument>()).filter { $0.key.hasPrefix("pantry-item-") }
                .map { try JSONDecoder().decode(PantryItem.self, from: $0.payload) }
            for item in items { try item.validate(catalog: catalog) }
            return items.filter { $0.quantity > 0 }.sorted { $0.ingredientID == $1.ingredientID ? $0.id.uuidString < $1.id.uuidString : $0.ingredientID < $1.ingredientID }
        } catch { throw PersistenceError.corruptData }
    }

    func writePantry(_ item: PantryItem, expectedRevision: UUID?, catalog: RecipeCatalog, at date: Date) throws {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        try updatePantry(item, expectedRevision: expectedRevision, catalog: catalog, at: date, documents: documents, context: context)
        try savePantryContext(context)
    }

    func removePantry(id: UUID, expectedRevision: UUID, catalog: RecipeCatalog, at date: Date) throws {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        guard let document = documents.first(where: { $0.key == pantryKey(id) }) else { throw PantryError.staleStock }
        var item = try JSONDecoder().decode(PantryItem.self, from: document.payload)
        item.quantity = 0; item.availabilityConfirmed = false
        try updatePantry(item, expectedRevision: expectedRevision, catalog: catalog, at: date, documents: documents, context: context)
        context.delete(document)
        try savePantryContext(context)
    }

    private func updatePantry(_ input: PantryItem, expectedRevision: UUID?, catalog: RecipeCatalog, at date: Date,
                              documents: [StoredDocument], context: ModelContext) throws {
        let key = pantryKey(input.id)
        let oldDocument = documents.first { $0.key == key }
        let previous = try oldDocument.map { try JSONDecoder().decode(PantryItem.self, from: $0.payload) }
        guard previous?.revision == expectedRevision else { throw PantryError.staleStock }
        if let previous {
            guard previous.ingredientID == input.ingredientID, previous.unit == input.unit else { throw PantryError.invalidQuantity }
        }
        var item = input
        item.reservations = previous?.reservations ?? [:]
        var room = item.quantity
        for owner in item.reservations.keys.sorted() {
            let kept = min(max(0, room), item.reservations[owner] ?? 0)
            item.reservations[owner] = kept; room -= kept
        }
        item.revision = UUID()
        try item.validate(catalog: catalog)
        if let activeDocument = documents.first(where: { $0.key == "activePlan" }) {
            let plan = try JSONDecoder().decode(WeeklyPlan.self, from: activeDocument.payload)
            if plan.closedAt == nil, var resources = plan.resources,
               let index = resources.pantryCredits?.firstIndex(where: { $0.id == item.id }) {
                resources.pantryCredits?[index].remainingQuantity = item.reservations[plan.id.uuidString] ?? 0
                resources.pantryCredits?[index].storage = item.storage
                resources.pantryCredits?[index].expiry = item.expiry
                resources.pantryCredits?[index].availabilityConfirmed = item.availabilityConfirmed
                let updated = try repricedPlan(plan, resources: resources, at: date)
                activeDocument.payload = try JSONEncoder().encode(updated)
            }
        }
        try putPantryDocument(item, key: key, documents: documents, context: context)
    }

    func closeCycle(_ confirmation: CarryoverConfirmation, at date: Date) throws {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let historyKey = "cycle-history-" + confirmation.planID.uuidString
        if let document = documents.first(where: { $0.key == historyKey }) {
            let previous = try JSONDecoder().decode(CycleHistory.self, from: document.payload)
            guard previous.confirmation == confirmation else { throw PantryError.invalidConfirmation }
            return
        }
        let (activeDocument, plan) = try activePantryPlan(documents)
        guard plan.id == confirmation.planID, plan.revision == confirmation.expectedRevision else { throw PantryError.staleStock }
        guard plan.closedAt == nil else { throw PantryError.cycleClosed }
        let sources = try StockAccounting.sources(plan: plan)
        guard Set(confirmation.items.map(\.sourceID)).count == confirmation.items.count else { throw PantryError.invalidConfirmation }
        for line in confirmation.items {
            guard let source = sources.first(where: { $0.id == line.sourceID }), line.quantity >= 0, line.quantity <= source.quantity,
                  line.quantity == 0 || line.availabilityConfirmed else { throw PantryError.invalidConfirmation }
        }
        for credit in plan.resources?.pantryCredits ?? [] {
            let key = pantryKey(credit.id)
            if credit.remainingQuantity == 0 { continue }
            guard let document = documents.first(where: { $0.key == key }) else { throw PantryError.staleStock }
            var item = try JSONDecoder().decode(PantryItem.self, from: document.payload)
            guard item.ingredientID == credit.ingredientID, item.unit == credit.unit, item.reservations[plan.id.uuidString] == credit.remainingQuantity, item.quantity >= credit.remainingQuantity else { throw PantryError.staleStock }
            item.quantity -= credit.remainingQuantity; item.reservations.removeValue(forKey: plan.id.uuidString); item.revision = UUID()
            if item.quantity == 0 { context.delete(document) }
            else { document.payload = try JSONEncoder().encode(item) }
        }
        for line in confirmation.items where line.quantity > 0 {
            guard let source = sources.first(where: { $0.id == line.sourceID }) else { throw PantryError.invalidConfirmation }
            let digest = SHA256.hash(data: Data((plan.id.uuidString + line.sourceID).utf8)).map { String(format: "%02x", $0) }.joined()
            let hex = String(digest.prefix(32))
            let value = [String(hex.prefix(8)), String(hex.dropFirst(8).prefix(4)), String(hex.dropFirst(12).prefix(4)), String(hex.dropFirst(16).prefix(4)), String(hex.suffix(12))].joined(separator: "-")
            guard let id = UUID(uuidString: value) else { throw PantryError.invalidConfirmation }
            let item = PantryItem(id: id, ingredientID: source.ingredientID, quantity: line.quantity, unit: source.unit,
                                  storage: line.storage, expiry: line.expiry, availabilityConfirmed: line.availabilityConfirmed, revision: UUID())
            try item.validate(catalog: plan.catalog)
            try putPantryDocument(item, key: pantryKey(id), documents: documents, context: context)
        }
        let closed = WeeklyPlan(id: plan.id, revision: UUID(), profile: plan.profile, catalog: plan.catalog, meals: plan.meals,
                                cart: plan.cart, totalMinorUnits: plan.totalMinorUnits, resources: plan.resources, offerOverrides: plan.offerOverrides,
                                closedAt: date, pricedAt: plan.pricedAt, reviewRequired: plan.reviewRequired)
        let history = CycleHistory(plan: closed, completedAt: date, confirmation: confirmation)
        activeDocument.payload = try JSONEncoder().encode(closed)
        try putPantryDocument(history, key: historyKey, documents: documents, context: context)
        try savePantryContext(context)
    }

    func startNextCycle(_ plan: WeeklyPlan, expectedPreviousRevision: UUID, now: Date) throws {
        try Task.checkCancellation()
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let (_, previous) = try activePantryPlan(documents)
        guard previous.revision == expectedPreviousRevision, previous.closedAt != nil, previous.id != plan.id else { throw PantryError.staleStock }
        guard plan.closedAt == nil, plan.resources?.purchases.isEmpty ?? true, plan.resources?.cookedMeals?.isEmpty ?? true,
              plan.totalMinorUnits <= plan.profile.budgetMinorUnits else { throw PantryError.invalidConfirmation }
        try CatalogValidator.validate(plan.catalog, allowDevelopment: true, now: now)
        try PlanValidation.validate(plan)
        try consumeRecipePins(for: plan, documents: documents)
        try reservePantryCredits(plan, documents: documents, context: context, at: now)
        try putPantryDocument(plan, key: "activePlan", documents: documents, context: context)
        try putPantryDocument(plan.profile, key: "profile", documents: documents, context: context)
        try savePantryContext(context)
    }

    func reservePantryCredits(_ plan: WeeklyPlan, documents: [StoredDocument], context: ModelContext, at now: Date) throws {
        let current = try StockAccounting.forecast(meals: plan.meals, profile: plan.profile, catalog: plan.catalog, resources: plan.resources, at: now)
        for credit in plan.resources?.pantryCredits ?? [] {
            guard let document = documents.first(where: { $0.key == pantryKey(credit.id) }) else { throw PantryError.staleStock }
            var item = try JSONDecoder().decode(PantryItem.self, from: document.payload)
            try item.validate(catalog: plan.catalog)
            guard item.ingredientID == credit.ingredientID, item.unit == credit.unit, item.revision == credit.sourceRevision, item.availabilityConfirmed, item.availableQuantity >= credit.originalQuantity,
                  item.expiry.map({ $0 >= now }) ?? true, current.creditUse[credit.id] == credit.originalQuantity else { throw PantryError.staleStock }
            item.reservations[plan.id.uuidString] = credit.originalQuantity; item.revision = UUID()
            document.payload = try JSONEncoder().encode(item)
        }
    }

    func applyPantryDebits(_ debits: [StockDebit], planID: UUID, catalog: RecipeCatalog, documents: [StoredDocument], context: ModelContext) throws {
        for debit in debits {
            guard let id = debit.pantryItemID else { continue }
            guard let document = documents.first(where: { $0.key == pantryKey(id) }) else { throw PantryError.staleStock }
            var item = try JSONDecoder().decode(PantryItem.self, from: document.payload)
            try item.validate(catalog: catalog)
            guard item.ingredientID == debit.ingredientID, item.quantity >= debit.quantity, (item.reservations[planID.uuidString] ?? 0) >= debit.quantity else { throw PantryError.staleStock }
            item.quantity -= debit.quantity; item.reservations[planID.uuidString, default: 0] -= debit.quantity; item.revision = UUID()
            document.payload = try JSONEncoder().encode(item)
        }
    }

    func releasePantryReservations(planID: UUID, documents: [StoredDocument]) throws {
        for document in documents where document.key.hasPrefix("pantry-item-") {
            var item = try JSONDecoder().decode(PantryItem.self, from: document.payload)
            if item.reservations.removeValue(forKey: planID.uuidString) != nil {
                item.revision = UUID(); document.payload = try JSONEncoder().encode(item)
            }
        }
    }

    func repricedPlan(_ plan: WeeklyPlan, resources: PlanResources, at date: Date) throws -> WeeklyPlan {
        let priced = try CartCalculator.calculate(CartRequest(meals: plan.meals, profile: plan.profile, catalog: plan.catalog,
                                                              resources: resources, offerOverrides: plan.offerOverrides, pricedAt: date))
        let updated = WeeklyPlan(id: plan.id, revision: UUID(), profile: plan.profile, catalog: plan.catalog, meals: plan.meals,
                                 cart: priced.items, totalMinorUnits: priced.totalMinorUnits, resources: resources, offerOverrides: plan.offerOverrides,
                                 pricedAt: date, reviewRequired: priced.totalMinorUnits > plan.profile.budgetMinorUnits)
        try PlanValidation.validate(updated)
        return updated
    }

    func activePantryPlan(_ documents: [StoredDocument]) throws -> (StoredDocument, WeeklyPlan) {
        guard let document = documents.first(where: { $0.key == "activePlan" }) else { throw PantryError.staleStock }
        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: document.payload)
        try PlanValidation.validate(plan)
        return (document, plan)
    }
    func pantryKey(_ id: UUID) -> String { "pantry-item-" + id.uuidString }
    func putPantryDocument<T: Encodable>(_ value: T, key: String, documents: [StoredDocument], context: ModelContext) throws {
        let payload = try JSONEncoder().encode(value)
        if let document = documents.first(where: { $0.key == key }) { document.payload = payload }
        else { context.insert(StoredDocument(key: key, payload: payload)) }
    }
    func savePantryContext(_ context: ModelContext) throws {
        do { try Task.checkCancellation(); try context.save() }
        catch is CancellationError { context.rollback(); throw CancellationError() }
        catch { context.rollback(); throw PersistenceError.saveFailed }
    }
}
