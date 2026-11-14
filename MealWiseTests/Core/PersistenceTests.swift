import Foundation
import Testing
import SwiftData
import Synchronization
@testable import MealWise

struct PersistenceTests {
    @Test func catalogRevalidatesClockOnEveryLoad() async throws {
        let clock = Mutex(Date(timeIntervalSince1970: 1794528000))
        let service = CatalogService(allowDevelopment: true, clock: { clock.withLock { $0 } })
        _ = try await service.loadCatalog()
        clock.withLock { $0 = Date(timeIntervalSince1970: 1893456000) }
        await #expect(throws: CatalogError.self) { try await service.loadCatalog() }
    }

    @Test(arguments: ["title", "equipment"])
    func incompleteRecipeRejected(field: String) async throws {
        let catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(catalog)) as? [String: Any])
        var recipes = try #require(json["recipes"] as? [[String: Any]])
        recipes[0][field] = field == "title" ? "  " : [""] as Any
        json["recipes"] = recipes
        let invalid = try JSONDecoder().decode(RecipeCatalog.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(throws: CatalogError.self) {
            try CatalogValidator.validate(invalid, allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000))
        }
    }

    @Test func profileSurvivesDiskStoreReopen() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { _ = try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "profile.store")
        let first = try await LocalStore.makeContainer(url: url)
        try await ProfileRepository(container: first).saveProfile(.fixture)
        let second = try await LocalStore.makeContainer(url: url)
        #expect(try await ProfileRepository(container: second).loadProfile() == .fixture)
    }

    @Test func invalidStoreLocationSurfacesOpenFailure() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data("not a directory".utf8).write(to: file)
        defer { _ = try? FileManager.default.removeItem(at: file) }
        await #expect(throws: PersistenceError.self) {
            try await LocalStore.makeContainer(url: file.appending(path: "profile.store"))
        }
    }

    @Test func profileRoundTrips() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let repository = ProfileRepository(container: container)
        #expect(try await repository.loadProfile() == nil)
        let profile = PlanningProfile.fixture
        try await repository.saveProfile(profile)
        let reopened = ProfileRepository(container: container)
        #expect(try await reopened.loadProfile() == profile)
    }

    @Test func invalidSavePreservesPreviousProfile() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let repository = ProfileRepository(container: container)
        let original = PlanningProfile.fixture
        try await repository.saveProfile(original)
        var invalid = original
        invalid.budgetMinorUnits = -1
        await #expect(throws: ProfileError.self) { try await repository.saveProfile(invalid) }
        #expect(try await repository.loadProfile() == original)
    }

    @Test func draftCatalogRejectedForLaunch() async throws {
        let service = CatalogService(allowDevelopment: false)
        await #expect(throws: CatalogError.self) { try await service.loadCatalog() }
    }

    @Test func approvedDevelopmentCatalogLoads() async throws {
        let catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        #expect(catalog.recipes.count == 12)
        #expect(catalog.offers.count == 19)
        #expect(catalog.ingredients.allSatisfy { !$0.allergensVerified })
    }

    @Test func expiredPricesRejected() async {
        await #expect(throws: CatalogError.self) {
            try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1893456000)).loadCatalog()
        }
    }

    @MainActor
    @Test func corruptProfileSurfacesTypedError() async throws {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(StoredDocument(key: "profile", payload: Data("invalid".utf8)))
        try context.save()
        let repository = ProfileRepository(container: container)
        await #expect(throws: PersistenceError.self) { try await repository.loadProfile() }
    }

    @Test func duplicateCatalogIDsRejected() async throws {
        let catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        let data = try JSONEncoder().encode(catalog)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var ingredients = try #require(json["ingredients"] as? [[String: Any]])
        ingredients.append(try #require(ingredients.first))
        json["ingredients"] = ingredients
        let invalid = try JSONDecoder().decode(RecipeCatalog.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(throws: CatalogError.self) {
            try CatalogValidator.validate(invalid, allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000))
        }
    }
}
