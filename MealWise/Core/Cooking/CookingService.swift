import Foundation
import SwiftData

protocol CookingServiceProtocol: Sendable {
    func markCooked(mealID: UUID, planID: UUID, expectedRevision: UUID?) async throws
    func previewMove(mealID: UUID, to date: Date, planID: UUID) async throws -> PlanChangePreview
    func loadProgress(mealID: UUID, planID: UUID) async throws -> CookingProgress
    func setStep(number: Int, complete: Bool, mealID: UUID, planID: UUID, recipeID: String) async throws -> CookingProgress
}

extension CookingServiceProtocol {
    func markCooked(mealID: UUID, planID: UUID) async throws { try await markCooked(mealID: mealID, planID: planID, expectedRevision: nil) }
}

actor CookingService: CookingServiceProtocol {
    private let plans: PlanRepository
    private let changes: any PlanChangeServiceProtocol
    private let clock: @Sendable () -> Date
    init(plans: PlanRepository, changes: any PlanChangeServiceProtocol, clock: @escaping @Sendable () -> Date = { .now }) {
        self.plans = plans; self.changes = changes; self.clock = clock
    }
    func markCooked(mealID: UUID, planID: UUID, expectedRevision: UUID? = nil) async throws { try await plans.completeCooking(mealID: mealID, planID: planID, date: clock(), expectedRevision: expectedRevision) }
    func previewMove(mealID: UUID, to date: Date, planID: UUID) async throws -> PlanChangePreview {
        guard let plan = try await plans.loadActivePlan(), plan.id == planID else { throw CookingError.staleMeal }
        return try await changes.preview(.move(mealID: mealID, date: date), in: plan)
    }
    func loadProgress(mealID: UUID, planID: UUID) async throws -> CookingProgress {
        try await plans.cookingProgress(mealID: mealID, planID: planID)
    }
    func setStep(number: Int, complete: Bool, mealID: UUID, planID: UUID, recipeID: String) async throws -> CookingProgress {
        try await plans.editCookingProgress(mealID: mealID, planID: planID, expectedRecipeID: recipeID) { progress, recipe in
            guard recipe.steps.contains(where: { $0.number == number }) else { throw CookingError.invalidStep }
            if complete { progress.completedSteps.insert(number) } else { progress.completedSteps.remove(number) }
        }
    }
}

extension PlanRepository {
    func completeCooking(mealID: UUID, planID: UUID, date: Date, expectedRevision: UUID?) throws {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let (document, plan, meal, recipe) = try cookingSnapshot(documents, planID: planID, mealID: mealID)
        if plan.cookedRecord(for: mealID) != nil { return }
        guard expectedRevision == nil || expectedRevision == plan.revision else { throw CookingError.staleMeal }
        var resources = plan.resources ?? PlanResources()
        var records = resources.cookedMeals ?? []
        records.append(CookedMealRecord(meal: meal, profile: plan.profile, recipe: recipe, completedAt: date))
        resources.cookedMeals = records
        try resources.validate(catalog: plan.catalog)
        let priced = try CartCalculator.calculate(CartRequest(meals: plan.meals, profile: plan.profile, catalog: plan.catalog,
                                                              resources: resources, offerOverrides: plan.offerOverrides))
        let updated = WeeklyPlan(id: plan.id, revision: UUID(), profile: plan.profile, catalog: plan.catalog, meals: plan.meals,
                                 cart: priced.items, totalMinorUnits: priced.totalMinorUnits, resources: resources, offerOverrides: plan.offerOverrides)
        try PlanValidation.validate(updated)
        document.payload = try JSONEncoder().encode(updated)
        let key = cookingKey(planID, mealID)
        if let progressDocument = documents.first(where: { $0.key == key }) {
            var progress = try JSONDecoder().decode(CookingProgress.self, from: progressDocument.payload)
            progress.timer = nil
            progressDocument.payload = try JSONEncoder().encode(progress)
        }
        try Task.checkCancellation(); try context.save()
    }

    func cookingProgress(mealID: UUID, planID: UUID) throws -> CookingProgress {
        let context = ModelContext(container)
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let (_, _, _, recipe) = try cookingSnapshot(documents, planID: planID, mealID: mealID)
        return try readCookingProgress(documents, planID: planID, mealID: mealID, recipe: recipe)
    }

    func editCookingProgress(mealID: UUID, planID: UUID, expectedRecipeID: String?,
                             edit: @Sendable (inout CookingProgress, Recipe) throws -> Void) throws -> CookingProgress {
        let context = ModelContext(container); context.autosaveEnabled = false
        let documents = try context.fetch(FetchDescriptor<StoredDocument>())
        let (_, plan, _, recipe) = try cookingSnapshot(documents, planID: planID, mealID: mealID)
        guard plan.cookedRecord(for: mealID) == nil else { throw CookingError.alreadyCooked }
        guard expectedRecipeID == nil || expectedRecipeID == recipe.id else { throw CookingError.staleMeal }
        var progress = try readCookingProgress(documents, planID: planID, mealID: mealID, recipe: recipe)
        try edit(&progress, recipe)
        let key = cookingKey(planID, mealID)
        let payload = try JSONEncoder().encode(progress)
        if let document = documents.first(where: { $0.key == key }) { document.payload = payload }
        else { context.insert(StoredDocument(key: key, payload: payload)) }
        try Task.checkCancellation(); try context.save()
        return progress
    }

    private func cookingKey(_ planID: UUID, _ mealID: UUID) -> String { "cooking-" + planID.uuidString + "-" + mealID.uuidString }
    private func readCookingProgress(_ documents: [StoredDocument], planID: UUID, mealID: UUID, recipe: Recipe) throws -> CookingProgress {
        let key = cookingKey(planID, mealID)
        guard let document = documents.first(where: { $0.key == key }) else { return CookingProgress(mealID: mealID, recipeID: recipe.id) }
        let progress = try JSONDecoder().decode(CookingProgress.self, from: document.payload)
        guard progress.recipeID == recipe.id else { return CookingProgress(mealID: mealID, recipeID: recipe.id) }
        guard progress.mealID == mealID, progress.completedSteps.isSubset(of: Set(recipe.steps.map(\.number))) else { throw PersistenceError.corruptData }
        return progress
    }
    private func cookingSnapshot(_ documents: [StoredDocument], planID: UUID, mealID: UUID) throws -> (StoredDocument, WeeklyPlan, ScheduledMeal, Recipe) {
        guard let document = documents.first(where: { $0.key == "activePlan" }) else { throw CookingError.staleMeal }
        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: document.payload)
        try PlanValidation.validate(plan)
        guard plan.id == planID, let meal = plan.meals.first(where: { $0.id == mealID }),
              let recipe = plan.catalog.recipes.first(where: { $0.id == meal.recipeID }) else { throw CookingError.staleMeal }
        return (document, plan, meal, recipe)
    }
}
