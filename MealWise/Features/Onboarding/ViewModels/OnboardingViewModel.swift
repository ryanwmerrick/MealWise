import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case goals, household, schedule, kitchen, time, skill, style, stores, diet, allergies, budget, summary
    }

    @Published var profile: PlanningProfile
    @Published var budgetText: String {
        didSet {
            do { profile.budgetMinorUnits = try Money.parse(budgetText).minorUnits }
            catch { profile.budgetMinorUnits = 0 }
        }
    }
    @Published private(set) var step: Step = .goals
    @Published private(set) var isBuilding = false
    @Published private(set) var preview: WeeklyPlan?
    @Published private(set) var errorMessage: String?
    private(set) var returnToSummary = false
    private let scheduleStart: Date
    private let originalScheduleDates: [Date]
    let services: AppServices
    private let basePlan: WeeklyPlan?
    let nextCycle: WeeklyPlan?
    let planningCatalog: RecipeCatalog
    private var changePreview: PlanChangePreview?

    init(profile: PlanningProfile, services: AppServices, now: Date = .now, basePlan: WeeklyPlan? = nil, nextCycle: WeeklyPlan? = nil, planningCatalog: RecipeCatalog? = nil) {
        self.profile = profile
        self.budgetText = NSDecimalNumber(decimal: Decimal(profile.budgetMinorUnits) / 100).stringValue
        self.services = services
        let calendar = Calendar.current
        scheduleStart = calendar.startOfDay(for: basePlan?.profile.days.min() ?? now)
        originalScheduleDates = basePlan?.profile.days ?? profile.days
        self.basePlan = basePlan; self.nextCycle = nextCycle; self.planningCatalog = planningCatalog ?? services.catalog
    }

    var canContinue: Bool {
        do { try profile.validate(); return true } catch { return false }
    }

    var upcomingDates: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: scheduleStart) else { return nil }
            return originalScheduleDates.first { calendar.isDate($0, inSameDayAs: day) } ?? day
        }.sorted { mondayFirstIndex($0) < mondayFirstIndex($1) }
    }

    func isDaySelected(_ date: Date) -> Bool {
        profile.days.contains { mondayFirstIndex($0) == mondayFirstIndex(date) }
    }

    private func mondayFirstIndex(_ date: Date) -> Int {
        (Calendar.current.component(.weekday, from: date) + 5) % 7
    }

    private func applySelectedWeekdays() {
        let original = profile.days
        let calendar = Calendar.current
        profile.days = upcomingDates.filter(isDaySelected).map { date in
            original.first { calendar.isDate($0, inSameDayAs: date) } ?? date
        }.sorted()
    }

    static func defaultProfile() -> PlanningProfile {
        let start = Calendar.current.startOfDay(for: .now)
        return PlanningProfile(budgetMinorUnits: 7000, adults: 1, children: 2,
                               days: (0..<5).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) },
                               mealSlots: [.dinner], cookingTime: .thirty, skill: .beginner,
                               storeID: "development-grocery", allergies: [], preferences: [])
    }

    func advance() {
        guard canContinue else { return }
        if step == .schedule { applySelectedWeekdays() }
        errorMessage = nil
        if returnToSummary { step = .summary; returnToSummary = false }
        else { step = Step(rawValue: step.rawValue + 1) ?? .summary }
    }

    func back() {
        errorMessage = nil
        if returnToSummary { step = .summary; returnToSummary = false }
        else { step = Step(rawValue: step.rawValue - 1) ?? .goals }
    }

    func edit(_ step: Step) { self.step = step; returnToSummary = true; preview = nil }

    func togglePreference<Value: Hashable>(
        _ value: Value, in keyPath: WritableKeyPath<OnboardingPreferences, Set<Value>>
    ) {
        var answers = profile.onboarding ?? OnboardingPreferences()
        if !answers[keyPath: keyPath].insert(value).inserted { answers[keyPath: keyPath].remove(value) }
        profile.onboarding = answers
    }

    func toggleKeto() {
        var answers = profile.onboarding ?? OnboardingPreferences()
        answers.keto.toggle()
        profile.onboarding = answers
    }

    func toggleDay(_ date: Date) {
        if isDaySelected(date) { profile.days.removeAll { mondayFirstIndex($0) == mondayFirstIndex(date) } }
        else { profile.days.append(date) }
        applySelectedWeekdays()
    }

    func toggleSlot(_ slot: MealSlot) {
        if profile.mealSlots.contains(slot) { profile.mealSlots.remove(slot) }
        else { profile.mealSlots.insert(slot) }
    }

    var wholeAllergyGroups: Set<Allergen> {
        profile.onboarding?.wholeAllergyGroups ?? profile.allergies
    }

    func toggleAllergy(_ allergy: Allergen) {
        var groups = wholeAllergyGroups
        if !groups.insert(allergy).inserted { groups.remove(allergy) }
        updateAllergies(groups: groups, details: profile.onboarding?.detailedAllergies ?? [])
    }

    func toggleDetailedAllergy(_ allergy: DetailedFoodAllergy) {
        var details = profile.onboarding?.detailedAllergies ?? []
        if !details.insert(allergy).inserted { details.remove(allergy) }
        updateAllergies(groups: wholeAllergyGroups, details: details)
    }

    private func updateAllergies(groups: Set<Allergen>, details: Set<DetailedFoodAllergy>) {
        var snapshot = profile
        var answers = snapshot.onboarding ?? OnboardingPreferences()
        answers.detailedAllergies = details
        answers.wholeAllergyGroups = groups
        snapshot.onboarding = answers
        snapshot.allergies = groups.union(details.map(\.group))
        profile = snapshot
    }

    func toggleAdditionalDiet(_ diet: AdditionalDietPreference) {
        var answers = profile.onboarding ?? OnboardingPreferences()
        var diets = answers.additionalDiets ?? []
        if !diets.insert(diet).inserted { diets.remove(diet) }
        answers.additionalDiets = diets
        profile.onboarding = answers
    }

    func togglePreference(_ preference: DietPreference) {
        if profile.preferences.contains(preference) { profile.preferences.remove(preference) }
        else { profile.preferences.insert(preference) }
    }

    func saveDraft() async -> PlanningProfile? {
        guard canContinue else { return nil }
        let snapshot = profile
        do {
            try await services.profiles.saveProfile(snapshot)
            try Task.checkCancellation()
            return snapshot
        }
        catch is CancellationError { return nil }
        catch {
            errorMessage = "Your answers could not be saved. Please retry before leaving setup."
            return nil
        }
    }

    func build(minimumDisplay: Duration = .zero) async {
        guard canContinue, !isBuilding else { return }
        isBuilding = true; errorMessage = nil; preview = nil
        defer { isBuilding = false }

        let clock = ContinuousClock()
        let finish = clock.now.advanced(by: minimumDisplay)
        await preparePreview()
        try? await clock.sleep(until: finish)
    }

    private func preparePreview() async {
        do {
            if let basePlan {
                let change = try await services.changes.preview(.profile(profile), in: basePlan)
                changePreview = change
                if change.constraint == .feasible { preview = change.proposedPlan }
                else { errorMessage = change.constraint.message }
                return
            }
            let request = try await planRequest(for: profile)
            let pins = request.pins
            guard pins.allSatisfy({ request.profile.days.contains($0.date) && request.profile.mealSlots.contains($0.slot) }) else {
                errorMessage = "A favorite pin no longer matches your selected dates or meal slots. Review or remove it in Favorites before building."
                return
            }
            let result = try await services.planner.generate(request)
            switch result {
            case .feasible(let plan): preview = plan
            case .invalidInputs: errorMessage = "Check your budget, household, selected meals and price dates, then try again."
            case .noFeasiblePlan:
                errorMessage = pins.isEmpty
                    ? "We couldn’t build a complete plan with your current choices. Review your budget, schedule, cooking time or kitchen equipment and try again. Meals must still match every selected allergy and dietary preference."
                    : "Your pinned favorites could not form a complete plan within this budget and food requirements. Review pins in Favorites or adjust your choices."
            case .searchLimit: errorMessage = "The search reached its limit before finding a complete plan. Try fewer meals or a higher budget."
            }
        } catch is CancellationError { return }
        catch { errorMessage = "The plan could not be built. Your previous plan is unchanged. Please retry." }
    }

    func budgetEstimate(for snapshot: PlanningProfile) async throws -> BudgetEstimate {
        if let basePlan {
            let result = try await services.changes.preview(.profile(snapshot), in: basePlan)
            if let plan = result.proposedPlan, result.constraint == .feasible {
                return .fits(plan.totalMinorUnits, plan.remainingMinorUnits)
            }
            return .message(result.constraint.message)
        }
        let request = try await planRequest(for: snapshot)
        switch try await services.planner.generate(request) {
        case .feasible(let plan): return .fits(plan.totalMinorUnits, plan.remainingMinorUnits)
        case .noFeasiblePlan: return .message("No complete plan fits these choices. Review your budget, schedule or kitchen equipment.")
        case .searchLimit: return .message("The search reached its limit before finding a plan.")
        case .invalidInputs: return .message("Check your setup answers to calculate an estimate.")
        }
    }

    enum BudgetEstimate {
        case fits(Int64, Int64)
        case message(String)
    }

    private func planRequest(for snapshot: PlanningProfile) async throws -> PlanRequest {
        let excluded = try await services.preferences.loadExcludedRecipeIDs()
        let stock = try await services.pantry.loadItems()
        let preferences = try await services.preferences.loadRecipePreferences()
        let pins = try await services.preferences.loadPins()
        return PlanRequest(profile: snapshot, catalog: planningCatalog, excludedRecipeIDs: excluded,
                           confirmedStock: stock, recipePreferences: preferences, pins: pins)
    }

    func acceptPreview() async -> WeeklyPlan? {
        guard let preview, !isBuilding else { return nil }
        isBuilding = true; defer { isBuilding = false }
        do {
            let accepted: WeeklyPlan
            if let changePreview {
                accepted = try await services.changes.accept(changePreview, expectedRevision: changePreview.baseRevision)
            } else if let nextCycle {
                try await services.cycles.accept(preview, expectedPreviousRevision: nextCycle.revision)
                accepted = preview
            } else {
                try await services.plans.saveActivePlan(preview)
                accepted = preview
            }
            self.preview = nil
            self.changePreview = nil
            return accepted
        } catch is CancellationError { return nil }
        catch {
            errorMessage = "The plan could not be saved. Your previous plan is unchanged. Please retry."
            return nil
        }
    }
}
