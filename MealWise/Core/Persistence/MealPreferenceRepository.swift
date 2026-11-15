import Foundation
import SwiftData

protocol MealPreferenceRepositoryProtocol: Sendable {
    func loadExcludedRecipeIDs() async throws -> Set<String>
    func setExcluded(recipeID: String, excluded: Bool) async throws
}

actor MealPreferenceRepository: MealPreferenceRepositoryProtocol {
    private let container: ModelContainer
    init(container: ModelContainer) { self.container = container }

    func loadExcludedRecipeIDs() async throws -> Set<String> {
        let context = ModelContext(container)
        do {
            let records = try context.fetch(FetchDescriptor(predicate: #Predicate<StoredDocument> { $0.key == "excludedRecipes" }))
            guard let payload = records.first?.payload else { return [] }
            return try JSONDecoder().decode(Set<String>.self, from: payload)
        } catch { throw PersistenceError.corruptData }
    }

    func setExcluded(recipeID: String, excluded: Bool) async throws {
        guard !recipeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PlanningError.invalidPlan }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let records = try context.fetch(FetchDescriptor(predicate: #Predicate<StoredDocument> { $0.key == "excludedRecipes" }))
            var ids = try records.first.map { try JSONDecoder().decode(Set<String>.self, from: $0.payload) } ?? []
            if excluded { ids.insert(recipeID) } else { ids.remove(recipeID) }
            let payload = try JSONEncoder().encode(ids)
            if let record = records.first { record.payload = payload }
            else { context.insert(StoredDocument(key: "excludedRecipes", payload: payload)) }
            try Task.checkCancellation()
            try context.save()
        } catch is CancellationError { context.rollback(); throw CancellationError() }
        catch { context.rollback(); throw PersistenceError.saveFailed }
    }
}
