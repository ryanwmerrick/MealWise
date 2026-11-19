import CryptoKit
import Foundation
import SwiftData

protocol PantryRepositoryProtocol: Sendable {
    func loadItems() async throws -> [PantryItem]
    func inventory(planID: UUID) async throws -> [PantryInventoryItem]
    func applyInventory(_ edits: [PantryInventoryEdit]) async throws
    func finishWeek(planID: UUID, revision: UUID) async throws
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
    func inventory(planID: UUID) async throws -> [PantryInventoryItem] { try await plans.pantryInventory(planID: planID, catalog: catalog) }
    func applyInventory(_ edits: [PantryInventoryEdit]) async throws { try await plans.editPantryInventory(edits, catalog: catalog, at: clock()) }
    func finishWeek(planID: UUID, revision: UUID) async throws { try await plans.finishPantryWeek(planID: planID, revision: revision, at: clock()) }
    func save(_ item: PantryItem, expectedRevision: UUID?) async throws { try await plans.writePantry(item, expectedRevision: expectedRevision, catalog: catalog, at: clock()) }
    func remove(id: UUID, expectedRevision: UUID) async throws { try await plans.removePantry(id: id, expectedRevision: expectedRevision, catalog: catalog, at: clock()) }
    func confirmCarryover(_ confirmation: CarryoverConfirmation) async throws { try await plans.closeCycle(confirmation, at: clock()) }
}

extension PlanRepository {
    func pantryInventory(planID: UUID, catalog: RecipeCatalog) throws -> [PantryInventoryItem] {
        let context = ModelContext(container)
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let (_, plan) = try activePantryPlan(documents)
        guard plan.id == planID else { throw PantryError.staleStock }
        let saved = try pantryItems(catalog: catalog).map { item in
            PantryInventoryItem(id: .saved(item.id),
                                name: item.customName ?? catalog.ingredients.first { $0.id == item.ingredientID }?.name ?? item.ingredientID,
                                quantity: item.quantity, unit: item.unit, acquiredAt: item.acquiredAt, revision: item.revision,
                                availabilityConfirmed: item.availabilityConfirmed, shelfDate: item.expiry, savedItem: item)
        }
        guard plan.closedAt == nil, let resources = plan.resources else { return saved }
        let dates = try purchaseDates(documents, planID: plan.id)
        let purchased = try StockAccounting.purchasedRemaining(resources).compactMap { id, quantity -> PantryInventoryItem? in
            guard quantity > 0, let ingredient = plan.catalog.ingredients.first(where: { $0.id == id }) else { return nil }
            return PantryInventoryItem(id: .purchased(id), name: ingredient.name, quantity: quantity, unit: ingredient.unit,
                                       acquiredAt: purchaseDate(for: id, remaining: quantity, resources: resources, dates: dates),
                                       revision: plan.revision, availabilityConfirmed: true, shelfDate: nil)
        }
        return (saved + purchased).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func editPantryInventory(_ edits: [PantryInventoryEdit], catalog: RecipeCatalog, at date: Date) throws {
        guard !edits.isEmpty else { return }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let (active, plan) = try activePantryPlan(documents)
        guard Set(edits.map(\.item.id)).count == edits.count else { throw PantryError.staleStock }
        let purchased = try StockAccounting.purchasedRemaining(plan.resources ?? PlanResources())
        var removedPurchases: [String: Int64] = [:]
        for edit in edits {
            guard edit.quantity >= 0, edit.quantity <= edit.item.quantity,
                  !edit.remove || edit.quantity == 0 else { throw PantryError.invalidQuantity }
            switch edit.item.id {
            case .saved(let id):
                guard let document = documents.first(where: { $0.key == pantryKey(id) }) else { throw PantryError.staleStock }
                var item = try JSONDecoder().decode(PantryItem.self, from: document.payload)
                guard item.revision == edit.item.revision else { throw PantryError.staleStock }
                if !edit.remove, item.quantity == edit.quantity && (!edit.confirmAvailability || item.availabilityConfirmed) { continue }
                item.quantity = edit.quantity
                if edit.confirmAvailability { item.availabilityConfirmed = true }
                try updatePantry(item, expectedRevision: item.revision, catalog: catalog, at: date, documents: documents, context: context)
                if edit.remove || (edit.quantity == 0 && item.unknownQuantity == nil) { context.delete(document) }
            case .purchased(let id):
                guard plan.closedAt == nil, edit.item.revision == plan.revision,
                      purchased[id] == edit.item.quantity else { throw PantryError.staleStock }
                let used = edit.item.quantity - edit.quantity
                if used > 0 { removedPurchases[id] = used }
            }
        }
        if !removedPurchases.isEmpty {
            let current = try JSONDecoder().decode(WeeklyPlan.self, from: active.payload)
            var resources = current.resources ?? PlanResources()
            var used = resources.usedOutsidePlan ?? [:]
            for (ingredientID, quantity) in removedPurchases {
                used[ingredientID] = try checkedSum(used[ingredientID, default: 0], quantity)
            }
            resources.usedOutsidePlan = used
            var updated = try repricedPlan(current, resources: resources, at: date)
            for document in documents where document.key.hasPrefix("pantry-item-") {
                var item = try JSONDecoder().decode(PantryItem.self, from: document.payload)
                guard removedPurchases[item.ingredientID] != nil, item.availableQuantity > 0 else { continue }
                let priorReservations = item.reservations
                if let reallocated = try updateActivePantryCredit(for: &item, plan: updated, at: date),
                   item.reservations != priorReservations {
                    updated = reallocated
                    item.revision = UUID()
                    document.payload = try JSONEncoder().encode(item)
                }
            }
            active.payload = try JSONEncoder().encode(updated)
        }
        try savePantryContext(context)
    }

    func finishPantryWeek(planID: UUID, revision: UUID, at date: Date) throws {
        let context = ModelContext(container)
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let (_, plan) = try activePantryPlan(documents)
        guard plan.id == planID, plan.revision == revision else { throw PantryError.staleStock }
        if plan.closedAt != nil { return }
        let carryover = try StockAccounting.sources(plan: plan).filter { $0.pantryItemID == nil }.map {
            CarryoverLine(sourceID: $0.id, quantity: $0.quantity, storage: $0.storage, expiry: $0.expiry, availabilityConfirmed: true)
        }
        try closeCycle(CarryoverConfirmation(planID: planID, expectedRevision: revision, items: carryover),
                       at: date, preserveSavedStock: true)
    }

    private func purchaseDates(_ documents: [StoredDocument], planID: UUID) throws -> [UUID: Date] {
        let summaries = try documents.filter { $0.key.hasPrefix("shopping-history-") }
            .map { try JSONDecoder().decode(ShoppingSummary.self, from: $0.payload) }
        return summaries.reduce(into: [:]) { dates, summary in
            if summary.trip.planID == planID { dates[summary.id] = summary.trip.finishedAt }
        }
    }

    private func purchaseDate(for ingredientID: String, remaining: Int64, resources: PlanResources,
                              dates: [UUID: Date]) -> Date? {
        // The oldest purchases are consumed first. Report the oldest acquisition still represented.
        let purchases = resources.purchases.filter { $0.ingredientID == ingredientID }.sorted {
            (dates[$0.tripID] ?? .distantPast) > (dates[$1.tripID] ?? .distantPast)
        }
        var quantity = remaining
        for purchase in purchases {
            if quantity <= purchase.quantity { return dates[purchase.tripID] }
            quantity -= purchase.quantity
        }
        return nil
    }

    func pantryItems(catalog: RecipeCatalog) throws -> [PantryItem] {
        let context = ModelContext(container)
        do {
            let items = try context.fetch(FetchDescriptor<StoredDocument>()).filter { $0.key.hasPrefix("pantry-item-") }
                .map { try JSONDecoder().decode(PantryItem.self, from: $0.payload) }
            for item in items { try item.validate(catalog: catalog) }
            return items.filter { $0.quantity > 0 || $0.unknownQuantity != nil }
                .sorted { $0.ingredientID == $1.ingredientID ? $0.id.uuidString < $1.id.uuidString : $0.ingredientID < $1.ingredientID }
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
            guard previous.ingredientID == input.ingredientID,
                  previous.unit == input.unit || previous.unknownQuantity != nil else { throw PantryError.invalidQuantity }
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
            if plan.closedAt == nil, let updated = try updateActivePantryCredit(for: &item, plan: plan, at: date) {
                activeDocument.payload = try JSONEncoder().encode(updated)
            }
        }
        try putPantryDocument(item, key: key, documents: documents, context: context)
    }

    private func updateActivePantryCredit(for item: inout PantryItem, plan: WeeklyPlan, at date: Date) throws -> WeeklyPlan? {
        var resources = plan.resources ?? PlanResources()
        var credits = resources.pantryCredits ?? []
        let id = item.id
        let index = credits.firstIndex { $0.id == id }
        if let index {
            credits[index].remainingQuantity = item.reservations[plan.id.uuidString] ?? 0
            credits[index].storage = item.storage
            credits[index].expiry = item.expiry
            credits[index].availabilityConfirmed = item.availabilityConfirmed
            resources.pantryCredits = credits
        }
        guard item.customName == nil, item.availabilityConfirmed, item.availableQuantity > 0,
              item.expiry.map({ $0 >= date }) ?? true else {
            return index == nil ? nil : try repricedPlan(plan, resources: resources, at: date)
        }
        let forecast = try StockAccounting.forecast(meals: plan.meals, profile: plan.profile, catalog: plan.catalog, resources: resources, at: date)
        let missing = forecast.net[item.ingredientID, default: 0]
        let quantity = min(missing, item.availableQuantity)
        guard quantity > 0 else { return index == nil ? nil : try repricedPlan(plan, resources: resources, at: date) }
        let prior = index.map { credits[$0] }
        let used = try (resources.cookedMeals ?? []).reduce(Int64(0)) { total, meal in
            try StockAccounting.debits(meal).filter { $0.pantryItemID == id }
                .reduce(total) { try checkedSum($0, $1.quantity) }
        }
        func creditsWithExtra(_ extra: Int64) throws -> [PantryCredit] {
            let remaining = try checkedSum(prior?.remainingQuantity ?? 0, extra)
            let total = max(prior?.originalQuantity ?? 0, try checkedSum(used, remaining))
            let credit = PantryCredit(id: id, ingredientID: item.ingredientID, unit: item.unit,
                                      sourceRevision: prior?.sourceRevision ?? item.revision,
                                      originalQuantity: total, remainingQuantity: remaining, storage: item.storage,
                                      expiry: item.expiry, availabilityConfirmed: true)
            var result = credits
            if let index { result[index] = credit }
            else { result.append(credit) }
            return result
        }
        var candidate = resources
        candidate.pantryCredits = try creditsWithExtra(quantity)
        let withStock = try StockAccounting.forecast(meals: plan.meals, profile: plan.profile, catalog: plan.catalog, resources: candidate, at: date)
        let usefulQuantity = missing - withStock.net[item.ingredientID, default: 0]
        guard usefulQuantity > 0 else { return index == nil ? nil : try repricedPlan(plan, resources: resources, at: date) }
        resources.pantryCredits = try creditsWithExtra(usefulQuantity)
        item.reservations[plan.id.uuidString] = try checkedSum(prior?.remainingQuantity ?? 0, usefulQuantity)
        return try repricedPlan(plan, resources: resources, at: date)
    }

    func closeCycle(_ confirmation: CarryoverConfirmation, at date: Date, preserveSavedStock: Bool = false) throws {
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
        if preserveSavedStock { try releasePantryReservations(planID: plan.id, documents: documents) }
        for credit in preserveSavedStock ? [] : (plan.resources?.pantryCredits ?? []) {
            let key = pantryKey(credit.id)
            if credit.remainingQuantity == 0 { continue }
            guard let document = documents.first(where: { $0.key == key }) else { throw PantryError.staleStock }
            var item = try JSONDecoder().decode(PantryItem.self, from: document.payload)
            guard item.ingredientID == credit.ingredientID, item.unit == credit.unit, item.reservations[plan.id.uuidString] == credit.remainingQuantity, item.quantity >= credit.remainingQuantity else { throw PantryError.staleStock }
            item.quantity -= credit.remainingQuantity; item.reservations.removeValue(forKey: plan.id.uuidString); item.revision = UUID()
            if item.quantity == 0 { context.delete(document) }
            else { document.payload = try JSONEncoder().encode(item) }
        }
        let dates = confirmation.items.isEmpty ? [:] : try purchaseDates(documents, planID: plan.id)
        for line in confirmation.items where line.quantity > 0 {
            guard let source = sources.first(where: { $0.id == line.sourceID }) else { throw PantryError.invalidConfirmation }
            let digest = SHA256.hash(data: Data((plan.id.uuidString + line.sourceID).utf8)).map { String(format: "%02x", $0) }.joined()
            let hex = String(digest.prefix(32))
            let value = [String(hex.prefix(8)), String(hex.dropFirst(8).prefix(4)), String(hex.dropFirst(12).prefix(4)), String(hex.dropFirst(16).prefix(4)), String(hex.suffix(12))].joined(separator: "-")
            guard let id = UUID(uuidString: value) else { throw PantryError.invalidConfirmation }
            let acquiredAt: Date?
            if let sourceID = source.pantryItemID {
                acquiredAt = try documents.first { $0.key == pantryKey(sourceID) }
                    .flatMap { try JSONDecoder().decode(PantryItem.self, from: $0.payload).acquiredAt }
            } else {
                acquiredAt = purchaseDate(for: source.ingredientID, remaining: source.quantity,
                                         resources: plan.resources ?? PlanResources(), dates: dates)
            }
            let item = PantryItem(id: id, ingredientID: source.ingredientID, quantity: line.quantity, unit: source.unit,
                                  storage: line.storage, expiry: line.expiry, availabilityConfirmed: line.availabilityConfirmed,
                                  revision: UUID(), acquiredAt: acquiredAt)
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
