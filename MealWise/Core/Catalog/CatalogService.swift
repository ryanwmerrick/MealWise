import Foundation

enum CatalogError: Error { case unavailable, invalidData, unreviewedContent, expiredPrices }

struct CatalogStore: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let region: String
}

struct RecipeCatalog: Codable, Equatable, Sendable {
    let version: String
    let reviewStatus: ContentReview
    let currencyCode: String
    let authorship: String
    let priceProvenance: String
    let stores: [CatalogStore]
    let ingredients: [Ingredient]
    let offers: [PackageOffer]
    let recipes: [Recipe]
}

protocol CatalogServiceProtocol: Sendable {
    func loadCatalog() async throws -> RecipeCatalog
}

actor CatalogService: CatalogServiceProtocol {
    private let allowDevelopment: Bool
    private let clock: @Sendable () -> Date

    init(allowDevelopment: Bool, now: Date? = nil) {
        self.allowDevelopment = allowDevelopment
        self.clock = { now ?? .now }
    }

    init(allowDevelopment: Bool, clock: @escaping @Sendable () -> Date) {
        self.allowDevelopment = allowDevelopment
        self.clock = clock
    }

    func loadCatalog() async throws -> RecipeCatalog {
        try Task.checkCancellation()
        guard let url = Bundle.main.url(forResource: "development-catalog", withExtension: "json") else {
            throw CatalogError.unavailable
        }
        let catalog: RecipeCatalog
        do {
            catalog = try JSONDecoder().decode(RecipeCatalog.self, from: Data(contentsOf: url))
        } catch { throw CatalogError.invalidData }
        try CatalogValidator.validate(catalog, allowDevelopment: allowDevelopment, now: clock())
        try Task.checkCancellation()
        return catalog
    }
}
