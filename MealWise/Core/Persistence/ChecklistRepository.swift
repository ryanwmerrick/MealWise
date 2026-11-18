import Foundation
import SwiftData

protocol ChecklistRepositoryProtocol: Sendable {
    func load(planID: UUID) async throws -> Set<String>
    func toggle(itemID: String, plan: WeeklyPlan) async throws
}

actor ChecklistRepository: ChecklistRepositoryProtocol {
    private let container: ModelContainer
    init(container: ModelContainer) { self.container = container }

    func load(planID: UUID) async throws -> Set<String> {
        let context = ModelContext(container)
        let key = "checklist-" + planID.uuidString
        do {
            let documents = try context.fetch(FetchDescriptor(predicate: #Predicate<StoredDocument> { $0.key == key }))
            guard let payload = documents.first?.payload else { return [] }
            return try JSONDecoder().decode(Set<String>.self, from: payload)
        } catch { throw PersistenceError.corruptData }
    }

    func toggle(itemID: String, plan: WeeklyPlan) async throws {
        guard plan.cart.contains(where: { $0.id == itemID }) else { throw PlanningError.invalidPlan }
        try Task.checkCancellation()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let key = "checklist-" + plan.id.uuidString
        do {
            let documents = try context.fetch(FetchDescriptor(predicate: #Predicate<StoredDocument> { $0.key == key }))
            var checked = try documents.first.map { try JSONDecoder().decode(Set<String>.self, from: $0.payload) } ?? []
            checked.formIntersection(Set(plan.cart.map(\.id)))
            if checked.contains(itemID) { checked.remove(itemID) } else { checked.insert(itemID) }
            let payload = try JSONEncoder().encode(checked)
            if let document = documents.first { document.payload = payload }
            else { context.insert(StoredDocument(key: key, payload: payload)) }
            try Task.checkCancellation()
            try context.save()
        } catch is CancellationError { context.rollback(); throw CancellationError() }
        catch { context.rollback(); throw PersistenceError.saveFailed }
    }
}
