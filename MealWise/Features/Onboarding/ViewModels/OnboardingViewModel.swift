import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var profile: PlanningProfile
    @Published var budgetText: String {
        didSet {
            do { profile.budgetMinorUnits = try Money.parse(budgetText).minorUnits }
            catch { profile.budgetMinorUnits = 0 }
        }
    }
    @Published private(set) var step = 0
    @Published private(set) var isBuilding = false
    @Published private(set) var preview: WeeklyPlan?
    @Published private(set) var errorMessage: String?
    private var returnToSummary = false
    private let services: AppServices
    private let today: Date

    init(profile: PlanningProfile, services: AppServices, now: Date = .now) {
        self.profile = profile
        self.budgetText = NSDecimalNumber(decimal: Decimal(profile.budgetMinorUnits) / 100).stringValue
        self.services = services
        self.today = now
    }

    var canContinue: Bool {
        do { try profile.validate(); return true } catch { return false }
    }

    var selectableDates: [Date] {
        let start = Calendar.current.startOfDay(for: today)
        let upcoming = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
        return Array(Set(upcoming + profile.days)).sorted()
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
        errorMessage = nil
        if returnToSummary { step = 7; returnToSummary = false }
        else { step = min(step + 1, 7) }
    }

    func back() { errorMessage = nil; step = max(step - 1, 0) }
    func edit(_ step: Int) { self.step = step; returnToSummary = true; preview = nil }

    func toggleDay(_ date: Date) {
        if profile.days.contains(date) { profile.days.removeAll { $0 == date } }
        else { profile.days.append(date); profile.days.sort() }
    }

    func toggleSlot(_ slot: MealSlot) {
        if profile.mealSlots.contains(slot) { profile.mealSlots.remove(slot) }
        else { profile.mealSlots.insert(slot) }
    }

    func toggleAllergy(_ allergy: Allergen) {
        if profile.allergies.contains(allergy) { profile.allergies.remove(allergy) }
        else { profile.allergies.insert(allergy) }
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

    func build() async {
        guard canContinue, !isBuilding else { return }
        isBuilding = true; errorMessage = nil; preview = nil
        defer { isBuilding = false }
        do {
            let result = try await services.planner.generate(PlanRequest(profile: profile, catalog: services.catalog))
            switch result {
            case .feasible(let plan): preview = plan
            case .invalidInputs: errorMessage = "Check your budget, household, selected meals and price dates, then try again."
            case .noFeasiblePlan: errorMessage = "No complete plan fits these choices. Try fewer meals, more time or a higher budget. Allergy requirements will never be relaxed; this development catalog has no supplier-verified allergens."
            case .searchLimit: errorMessage = "The search reached its limit before finding a complete plan. Try fewer meals or a higher budget."
            }
        } catch is CancellationError { return }
        catch { errorMessage = "The plan could not be built. Your previous plan is unchanged. Please retry." }
    }

    func acceptPreview() async -> WeeklyPlan? {
        guard let preview else { return nil }
        do {
            try await services.plans.saveActivePlan(preview)
            self.preview = nil
            return preview
        } catch is CancellationError { return nil }
        catch {
            errorMessage = "The plan could not be saved. Your previous plan is unchanged. Please retry."
            return nil
        }
    }
}
