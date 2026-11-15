import Foundation
import SwiftData

protocol PlanRepositoryProtocol: Sendable {
    func loadActivePlan() async throws -> WeeklyPlan?
    func saveActivePlan(_ plan: WeeklyPlan) async throws
    func resetActivePlan() async throws
    func commit(_ plan: WeeklyPlan, expectedRevision: UUID) async throws
}

actor PlanRepository: PlanRepositoryProtocol {
    private let container: ModelContainer
    init(container: ModelContainer) { self.container = container }

    func resetActivePlan() async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let documents = try context.fetch(FetchDescriptor<StoredDocument>())
            for document in documents where document.key == "activePlan" || document.key == "profile" {
                context.delete(document)
            }
            try Task.checkCancellation()
            try context.save()
        } catch is CancellationError { context.rollback(); throw CancellationError() }
        catch { context.rollback(); throw PersistenceError.saveFailed }
    }

    func loadActivePlan() async throws -> WeeklyPlan? {
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
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let documents = try context.fetch(FetchDescriptor<StoredDocument>())
            if let expectedRevision {
                guard let active = documents.first(where: { $0.key == "activePlan" }) else { throw PlanChangeError.stalePreview }
                let previous = try JSONDecoder().decode(WeeklyPlan.self, from: active.payload)
                guard previous.id == plan.id, previous.revision == expectedRevision else { throw PlanChangeError.stalePreview }
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
            let payloads = [("activePlan", try JSONEncoder().encode(plan)), ("profile", try JSONEncoder().encode(plan.profile))]
            for (key, payload) in payloads {
                if let existing = documents.first(where: { $0.key == key }) { existing.payload = payload }
                else { context.insert(StoredDocument(key: key, payload: payload)) }
            }
            try Task.checkCancellation()
            try context.save()
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
