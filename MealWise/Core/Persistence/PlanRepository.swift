import Foundation
import SwiftData

struct PlanArchive: Codable, Equatable, Sendable, Identifiable {
    let plan: WeeklyPlan
    let archivedAt: Date
    var id: UUID { plan.id }
}

protocol PlanRepositoryProtocol: Sendable {
    func loadActivePlan() async throws -> WeeklyPlan?
    func saveActivePlan(_ plan: WeeklyPlan) async throws
    func resetActivePlan() async throws
    func eraseLocalData() async throws
    func commit(_ plan: WeeklyPlan, expectedRevision: UUID) async throws
}

actor PlanRepository: PlanRepositoryProtocol {
    let container: ModelContainer
    let clock: @Sendable () -> Date
    init(container: ModelContainer, clock: @escaping @Sendable () -> Date = { .now }) { self.container = container; self.clock = clock }

    func resetActivePlan() async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let documents = try context.fetch(FetchDescriptor<StoredDocument>())
            if let active = documents.first(where: { $0.key == "activePlan" }) {
                let plan = try JSONDecoder().decode(WeeklyPlan.self, from: active.payload)
                try PlanValidation.validate(plan)
                try releasePantryReservations(planID: plan.id, documents: documents)
                if plan.resources?.purchases.isEmpty == false || plan.resources?.cookedMeals?.isEmpty == false {
                    let key = "archived-plan-" + plan.id.uuidString
                    if !documents.contains(where: { $0.key == key }) {
                        let archive = PlanArchive(plan: plan, archivedAt: .now)
                        context.insert(StoredDocument(key: key, payload: try JSONEncoder().encode(archive)))
                    }
                }
            }
            for document in documents where document.key == "activePlan" || document.key == "profile" || document.key == "next-plan-pins" {
                context.delete(document)
            }
            try Task.checkCancellation()
            try context.save()
        } catch is CancellationError { context.rollback(); throw CancellationError() }
        catch { context.rollback(); throw PersistenceError.saveFailed }
    }

    func eraseLocalData() async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        for document in documents { context.delete(document) }
        try savePantryContext(context)
    }

    func loadArchivedPlans() throws -> [PlanArchive] {
        let context = ModelContext(container)
        do {
            let archives = try context.fetch(FetchDescriptor<StoredDocument>()).filter { $0.key.hasPrefix("archived-plan-") }
                .map { try JSONDecoder().decode(PlanArchive.self, from: $0.payload) }
            for archive in archives { try PlanValidation.validate(archive.plan) }
            return archives.sorted { $0.archivedAt > $1.archivedAt }
        } catch { throw PersistenceError.corruptData }
    }

    func loadActivePlan() async throws -> WeeklyPlan? {
        try reconcileExpiredPantry(at: clock())
        let context = ModelContext(container)
        do {
            let documents = try context.fetch(FetchDescriptor(predicate: #Predicate<StoredDocument> { $0.key == "activePlan" }))
            guard let payload = documents.first?.payload else { return nil }
            let plan = try JSONDecoder().decode(WeeklyPlan.self, from: payload)
            try PlanValidation.validate(plan)
            return plan
        } catch { throw PersistenceError.corruptData }
    }

    func saveActivePlan(_ plan: WeeklyPlan) async throws {
        try writePlan(plan, expectedRevision: nil)
    }

    func commit(_ plan: WeeklyPlan, expectedRevision: UUID) async throws {
        try writePlan(plan, expectedRevision: expectedRevision)
    }

    private func writePlan(_ plan: WeeklyPlan, expectedRevision: UUID?) throws {
        try Task.checkCancellation()
        try PlanValidation.validate(plan)
        guard plan.totalMinorUnits <= plan.profile.budgetMinorUnits else { throw PlanChangeError.infeasible }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let documents = try context.fetch(FetchDescriptor<StoredDocument>())
            if expectedRevision == nil { try consumeRecipePins(for: plan, documents: documents) }
            if let expectedRevision {
                guard let active = documents.first(where: { $0.key == "activePlan" }) else { throw PlanChangeError.stalePreview }
                let previous = try JSONDecoder().decode(WeeklyPlan.self, from: active.payload)
                guard previous.closedAt == nil else { throw PantryError.cycleClosed }
                guard previous.id == plan.id, previous.revision == expectedRevision, previous.resources == plan.resources else { throw PlanChangeError.stalePreview }
                let key = "checklist-" + plan.id.uuidString
                if let checklist = documents.first(where: { $0.key == key }) {
                    var checked = try JSONDecoder().decode(Set<String>.self, from: checklist.payload)
                    let changed = Set(plan.cart.filter { item in
                        guard let old = previous.cart.first(where: { $0.id == item.id }) else { return true }
                        return old.packageCount != item.packageCount || old.offerID != item.offerID
                    }.map(\.id))
                    checked.formIntersection(Set(plan.cart.map(\.id)))
                    checked.subtract(changed)
                    checklist.payload = try JSONEncoder().encode(checked)
                }
            }
            if expectedRevision == nil, plan.resources?.pantryCredits?.isEmpty == false {
                guard !documents.contains(where: { $0.key == "activePlan" }) else { throw PantryError.activeCycle }
                try reservePantryCredits(plan, documents: documents, context: context, at: clock())
            }
            let payloads = [("activePlan", try JSONEncoder().encode(plan)), ("profile", try JSONEncoder().encode(plan.profile))]
            for (key, payload) in payloads {
                if let existing = documents.first(where: { $0.key == key }) { existing.payload = payload }
                else { context.insert(StoredDocument(key: key, payload: payload)) }
            }
            try Task.checkCancellation()
            try context.save()
        } catch let error as PantryError {
            context.rollback()
            throw error
        } catch let error as PlanChangeError {
            context.rollback()
            throw error
        } catch is CancellationError {
            context.rollback()
            throw CancellationError()
        } catch {
            context.rollback()
            throw PersistenceError.saveFailed
        }
    }
}
