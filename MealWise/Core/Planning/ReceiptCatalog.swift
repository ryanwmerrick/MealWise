import Foundation

struct ReceiptPriceObservation: Sendable, Identifiable {
    let id: String
    let offerID: String
    let packageCount: Int64
    let actualMinorUnits: Int64
    let recordedAt: Date
    var estimatedUnitMinorUnits: Int64 {
        guard packageCount > 0, actualMinorUnits >= 0 else { return 0 }
        return actualMinorUnits / packageCount + (actualMinorUnits % packageCount == 0 ? 0 : 1)
    }
}

enum ReceiptCatalog {
    static func observations(from summaries: [ShoppingSummary], catalog: RecipeCatalog) -> [ReceiptPriceObservation] {
        var seen = Set<String>()
        return summaries.sorted { ($0.trip.finishedAt ?? .distantPast) > ($1.trip.finishedAt ?? .distantPast) }.flatMap { summary in
            summary.trip.lines.compactMap { line -> ReceiptPriceObservation? in
                guard line.checked, let actual = line.actualMinorUnits, actual > 0, line.packageCount > 0,
                      let date = summary.trip.finishedAt,
                      catalog.offers.contains(where: { $0.id == line.offerID && $0.storeID == summary.trip.storeID && $0.packageQuantity == line.packageQuantity && $0.unit == line.unit }),
                      seen.insert(line.offerID).inserted else { return nil }
                return ReceiptPriceObservation(id: summary.id.uuidString + line.id.uuidString, offerID: line.offerID,
                                               packageCount: line.packageCount, actualMinorUnits: actual, recordedAt: date)
            }
        }
    }
    static func apply(_ approved: [ReceiptPriceObservation], to catalog: RecipeCatalog, at date: Date) throws -> RecipeCatalog {
        guard !approved.isEmpty else { return catalog }
        guard Set(approved.map(\.offerID)).count == approved.count, approved.allSatisfy({ observation in observation.recordedAt <= date && observation.estimatedUnitMinorUnits > 0 && catalog.offers.contains(where: { $0.id == observation.offerID }) }) else { throw CatalogError.invalidData }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withFullDate]
        let offers = catalog.offers.map { offer in
            guard let observation = approved.first(where: { $0.offerID == offer.id }) else { return offer }
            return PackageOffer(id: offer.id, ingredientID: offer.ingredientID, storeID: offer.storeID, packageQuantity: offer.packageQuantity,
                                unit: offer.unit, priceMinorUnits: observation.estimatedUnitMinorUnits, currencyCode: offer.currencyCode,
                                priceDate: formatter.string(from: observation.recordedAt), validThrough: offer.validThrough,
                                provenance: "User-approved development estimate from a recorded receipt line; per-package average rounded up. Original catalog validity is unchanged.", reviewStatus: offer.reviewStatus)
        }
        let updated = RecipeCatalog(version: catalog.version + "-receipt-review-" + formatter.string(from: date), reviewStatus: catalog.reviewStatus,
                                    currencyCode: catalog.currencyCode, authorship: catalog.authorship,
                                    priceProvenance: "Development estimates include explicitly reviewed receipt observations. Actual receipts remain unchanged; no current store price is guaranteed.",
                                    stores: catalog.stores, ingredients: catalog.ingredients, offers: offers, recipes: catalog.recipes)
        try CatalogValidator.validate(updated, allowDevelopment: true, now: date)
        return updated
    }
}
