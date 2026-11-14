import Foundation

enum CatalogValidator {
    static func validate(_ catalog: RecipeCatalog, allowDevelopment: Bool, now: Date) throws {
        guard approved(catalog.reviewStatus, allowDevelopment), hasText(catalog.version) else {
            throw CatalogError.unreviewedContent
        }
        guard catalog.currencyCode == "USD", hasText(catalog.authorship),
              hasText(catalog.priceProvenance), !catalog.recipes.isEmpty,
              !catalog.ingredients.isEmpty, !catalog.stores.isEmpty else { throw CatalogError.invalidData }
        try unique(catalog.ingredients.map(\.id))
        try unique(catalog.recipes.map(\.id))
        try unique(catalog.offers.map(\.id))
        try unique(catalog.stores.map(\.id))
        for ingredient in catalog.ingredients {
            guard approved(ingredient.reviewStatus, allowDevelopment), hasText(ingredient.name),
                  ingredient.unit == ingredient.unit.canonicalUnit else { throw CatalogError.invalidData }
            if !allowDevelopment && !ingredient.allergensVerified { throw CatalogError.unreviewedContent }
        }
        for offer in catalog.offers { try validate(offer, catalog: catalog, allowDevelopment: allowDevelopment, now: now) }
        for recipe in catalog.recipes { try validate(recipe, catalog: catalog, allowDevelopment: allowDevelopment) }
    }

    private static func validate(_ offer: PackageOffer, catalog: RecipeCatalog, allowDevelopment: Bool, now: Date) throws {
        guard approved(offer.reviewStatus, allowDevelopment), offer.packageQuantity > 0,
              offer.priceMinorUnits > 0, offer.currencyCode == catalog.currencyCode,
              hasText(offer.provenance),
              catalog.stores.contains(where: { $0.id == offer.storeID }),
              let ingredient = catalog.ingredients.first(where: { $0.id == offer.ingredientID }),
              ingredient.unit == offer.unit else { throw CatalogError.invalidData }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: offer.priceDate + "T00:00:00Z"),
              let expiry = formatter.date(from: offer.validThrough + "T23:59:59Z"), date <= expiry else {
            throw CatalogError.invalidData
        }
        guard date <= now, now <= expiry else { throw CatalogError.expiredPrices }
    }

    private static func validate(_ recipe: Recipe, catalog: RecipeCatalog, allowDevelopment: Bool) throws {
        guard approved(recipe.reviewStatus, allowDevelopment), hasText(recipe.title),
              recipe.baseAdultPortions > 0, recipe.minutes > 0, !recipe.mealSlots.isEmpty,
              !recipe.ingredients.isEmpty, !recipe.steps.isEmpty, !recipe.equipment.isEmpty,
              recipe.equipment.allSatisfy(hasText),
              recipe.steps.map(\.number) == Array(1...recipe.steps.count),
              recipe.steps.allSatisfy({ !$0.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CatalogError.invalidData
        }
        try unique(recipe.ingredients.map(\.ingredientID))
        for requirement in recipe.ingredients {
            guard requirement.quantity > 0,
                  let ingredient = catalog.ingredients.first(where: { $0.id == requirement.ingredientID }),
                  ingredient.unit == requirement.unit,
                  catalog.stores.allSatisfy({ store in
                      catalog.offers.contains { $0.ingredientID == requirement.ingredientID && $0.storeID == store.id }
                  }) else { throw CatalogError.invalidData }
        }
    }

    private static func approved(_ review: ContentReview, _ allowDevelopment: Bool) -> Bool {
        review == .launchReviewed || (allowDevelopment && review == .developmentApproved)
    }

    private static func unique(_ ids: [String]) throws {
        guard Set(ids).count == ids.count, ids.allSatisfy(hasText) else { throw CatalogError.invalidData }
    }

    private static func hasText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
