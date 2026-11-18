import Foundation
import SwiftData

protocol MealPreferenceRepositoryProtocol: Sendable {
    func loadExcludedRecipeIDs() async throws -> Set<String>
    func setExcluded(recipeID: String, excluded: Bool) async throws
    func loadRecipePreferences() async throws -> [RecipePreference]
    func setFavorite(recipeID: String, favorite: Bool) async throws
    func rate(mealID: UUID, rating: MealRating) async throws
    func loadRatings() async throws -> [MealRatingRecord]
    func loadPins() async throws -> [RecipePin]
    func savePin(_ pin: RecipePin) async throws
    func removePin(_ pin: RecipePin) async throws
}

actor MealPreferenceRepository: MealPreferenceRepositoryProtocol {
    private let plans: PlanRepository
    init(container: ModelContainer) { plans = PlanRepository(container: container) }
    init(plans: PlanRepository) { self.plans = plans }
    func loadExcludedRecipeIDs() async throws -> Set<String> { try await plans.excludedRecipeIDs() }
    func setExcluded(recipeID: String, excluded: Bool) async throws { try await plans.editRecipePreference(recipeID: recipeID, excluded: excluded) }
    func loadRecipePreferences() async throws -> [RecipePreference] { try await plans.recipePreferences() }
    func setFavorite(recipeID: String, favorite: Bool) async throws { try await plans.editRecipePreference(recipeID: recipeID, favorite: favorite) }
    func rate(mealID: UUID, rating: MealRating) async throws { try await plans.rateCookedMeal(mealID: mealID, rating: rating) }
    func loadRatings() async throws -> [MealRatingRecord] { try await plans.mealRatings() }
    func loadPins() async throws -> [RecipePin] { try await plans.recipePins() }
    func savePin(_ pin: RecipePin) async throws { try await plans.saveRecipePin(pin) }
    func removePin(_ pin: RecipePin) async throws { try await plans.removeRecipePin(pin) }
}

extension PlanRepository {
    func recipePreferences() throws -> [RecipePreference] {
        let documents = try ModelContext(container).fetch(FetchDescriptor<StoredDocument>())
        var preferences = try documents.filter { $0.key.hasPrefix("recipe-preference-") }.map { try JSONDecoder().decode(RecipePreference.self, from: $0.payload) }
        let legacy = try documents.first { $0.key == "excludedRecipes" }.map { try JSONDecoder().decode(Set<String>.self, from: $0.payload) } ?? []
        for id in legacy where !preferences.contains(where: { $0.recipeID == id }) {
            preferences.append(RecipePreference(recipeID: id, rating: nil, favorite: false, excluded: true))
        }
        guard Set(preferences.map(\.recipeID)).count == preferences.count else { throw PersistenceError.corruptData }
        return preferences.sorted { $0.recipeID < $1.recipeID }
    }
    func excludedRecipeIDs() throws -> Set<String> { Set(try recipePreferences().filter(\.excluded).map(\.recipeID)) }
    func editRecipePreference(recipeID: String, favorite: Bool? = nil, excluded: Bool? = nil) throws {
        guard !recipeID.isEmpty, recipeID.count <= 128 else { throw PlanningError.invalidPlan }
        var preference = try recipePreferences().first { $0.recipeID == recipeID } ?? RecipePreference(recipeID: recipeID, rating: nil, favorite: false, excluded: false)
        if let favorite { preference.favorite = favorite }
        if let excluded { preference.excluded = excluded }
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        try putPantryDocument(preference, key: "recipe-preference-" + recipeID, documents: documents, context: context)
        try savePantryContext(context)
    }
    func mealRatings() throws -> [MealRatingRecord] {
        try ModelContext(container).fetch(FetchDescriptor<StoredDocument>()).filter { $0.key.hasPrefix("meal-rating-") }
            .map { try JSONDecoder().decode(MealRatingRecord.self, from: $0.payload) }
    }
    func rateCookedMeal(mealID: UUID, rating: MealRating) throws {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        var recorded: CookedMealRecord?
        for document in documents {
            let plan: WeeklyPlan?
            if document.key == "activePlan" { plan = try JSONDecoder().decode(WeeklyPlan.self, from: document.payload) }
            else if document.key.hasPrefix("cycle-history-") { plan = try JSONDecoder().decode(CycleHistory.self, from: document.payload).plan }
            else if document.key.hasPrefix("archived-plan-") { plan = try JSONDecoder().decode(PlanArchive.self, from: document.payload).plan }
            else { plan = nil }
            if let record = plan?.cookedRecord(for: mealID) { recorded = record; break }
        }
        guard let recorded else { throw CookingError.insufficientStock }
        let id = recorded.recipe.id
        var preference = try recipePreferences().first { $0.recipeID == id } ?? RecipePreference(recipeID: id, rating: nil, favorite: false, excluded: false)
        preference.rating = rating; preference.favorite = rating == .liked
        try putPantryDocument(preference, key: "recipe-preference-" + id, documents: documents, context: context)
        try putPantryDocument(MealRatingRecord(mealID: mealID, recipeID: id, rating: rating), key: "meal-rating-" + mealID.uuidString, documents: documents, context: context)
        try savePantryContext(context)
    }
    func recipePins() throws -> [RecipePin] {
        let documents = try ModelContext(container).fetch(FetchDescriptor<StoredDocument>())
        return try documents.first { $0.key == "next-plan-pins" }.map { try JSONDecoder().decode([RecipePin].self, from: $0.payload) } ?? []
    }
    func saveRecipePin(_ pin: RecipePin) throws {
        guard !pin.recipeID.isEmpty, pin.recipeID.count <= 128,
              pin.date.timeIntervalSince1970.isFinite else { throw PlanningError.invalidPlan }
        let preference = try recipePreferences().first { $0.recipeID == pin.recipeID }
        guard preference?.favorite == true, preference?.excluded == false else { throw PlanChangeError.ineligibleRecipe }
        var pins = try recipePins()
        pins.removeAll { $0.id == pin.id }
        guard pins.count < 21 else { throw PlanningError.invalidPlan }
        pins.append(pin)
        try storeRecipePins(pins)
    }

    func removeRecipePin(_ pin: RecipePin) throws {
        var pins = try recipePins()
        guard let index = pins.firstIndex(of: pin) else { return }
        pins.remove(at: index)
        try storeRecipePins(pins)
    }

    private func storeRecipePins(_ pins: [RecipePin]) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        try putPantryDocument(pins, key: "next-plan-pins", documents: documents, context: context)
        try savePantryContext(context)
    }

    func consumeRecipePins(for plan: WeeklyPlan, documents: [StoredDocument]) throws {
        let excluded = try excludedRecipeIDs()
        guard plan.meals.allSatisfy({ !excluded.contains($0.recipeID) }) else { throw PlanChangeError.ineligibleRecipe }
        guard let document = documents.first(where: { $0.key == "next-plan-pins" }) else { return }
        let pins = try JSONDecoder().decode([RecipePin].self, from: document.payload)
        guard pins.allSatisfy({ pin in plan.meals.contains { $0.date == pin.date && $0.slot == pin.slot && $0.recipeID == pin.recipeID } }) else { throw PlanChangeError.stalePreview }
        document.payload = try JSONEncoder().encode([RecipePin]())
    }
}
