import Foundation
import SwiftData

protocol PlanRepositoryProtocol: Sendable {
    func loadActivePlan() async throws -> WeeklyPlan?
    func saveActivePlan(_ plan: WeeklyPlan) async throws
    func resetActivePlan() async throws
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
        try Task.checkCancellation()
        try PlanValidation.validate(plan)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let documents = try context.fetch(FetchDescriptor<StoredDocument>())
            let payloads = [("activePlan", try JSONEncoder().encode(plan)), ("profile", try JSONEncoder().encode(plan.profile))]
            for (key, payload) in payloads {
                if let existing = documents.first(where: { $0.key == key }) { existing.payload = payload }
                else { context.insert(StoredDocument(key: key, payload: payload)) }
            }
            try Task.checkCancellation()
            try context.save()
        } catch is CancellationError {
            context.rollback()
            throw CancellationError()
        } catch {
            context.rollback()
            throw PersistenceError.saveFailed
        }
    }
}
