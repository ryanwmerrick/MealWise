import Foundation
import SwiftData

protocol ProfileRepositoryProtocol: Sendable {
    func loadProfile() async throws -> PlanningProfile?
    func saveProfile(_ profile: PlanningProfile) async throws
}

actor ProfileRepository: ProfileRepositoryProtocol {
    private let container: ModelContainer

    init(container: ModelContainer) { self.container = container }

    func loadProfile() async throws -> PlanningProfile? {
        try Task.checkCancellation()
        let context = ModelContext(container)
        let documents: [StoredDocument]
        do { documents = try context.fetch(FetchDescriptor(predicate: #Predicate<StoredDocument> { $0.key == "profile" })) }
        catch { throw PersistenceError.readFailed }
        guard let document = documents.first else { return nil }
        do {
            let profile = try JSONDecoder().decode(PlanningProfile.self, from: document.payload)
            try profile.validate()
            return profile
        } catch { throw PersistenceError.corruptData }
    }

    func saveProfile(_ profile: PlanningProfile) async throws {
        try Task.checkCancellation()
        try profile.validate()
        let payload: Data
        do { payload = try JSONEncoder().encode(profile) }
        catch { throw PersistenceError.saveFailed }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let documents = try context.fetch(FetchDescriptor(predicate: #Predicate<StoredDocument> { $0.key == "profile" }))
            if let document = documents.first { document.payload = payload }
            else { context.insert(StoredDocument(key: "profile", payload: payload)) }
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
