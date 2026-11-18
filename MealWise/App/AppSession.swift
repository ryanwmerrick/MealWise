import Foundation
import Observation

struct AppServices: Sendable {
    let catalog: RecipeCatalog
    let profiles: any ProfileRepositoryProtocol
    let plans: any PlanRepositoryProtocol
    let planner: any PlanServiceProtocol
    let checklist: any ChecklistRepositoryProtocol
    let preferences: any MealPreferenceRepositoryProtocol
    let changes: any PlanChangeServiceProtocol
    let shopping: any ShoppingServiceProtocol
    let cooking: any CookingServiceProtocol
    let timers: any TimerServiceProtocol
    let pantry: any PantryRepositoryProtocol
    let history: any HistoryRepositoryProtocol
    let cycles: any NextCycleServiceProtocol

    init(catalog: RecipeCatalog, profiles: any ProfileRepositoryProtocol, plans: any PlanRepositoryProtocol,
         planner: any PlanServiceProtocol, checklist: any ChecklistRepositoryProtocol,
         preferences: any MealPreferenceRepositoryProtocol, shopping: any ShoppingServiceProtocol, cooking: any CookingServiceProtocol, timers: any TimerServiceProtocol, pantry: any PantryRepositoryProtocol, history: any HistoryRepositoryProtocol, cycles: any NextCycleServiceProtocol, changes: (any PlanChangeServiceProtocol)? = nil) {
        self.catalog = catalog; self.profiles = profiles; self.plans = plans; self.planner = planner
        self.checklist = checklist; self.preferences = preferences
        self.shopping = shopping; self.cooking = cooking; self.timers = timers
        self.pantry = pantry; self.history = history; self.cycles = cycles
        self.changes = changes ?? PlanChangeService(plans: plans, planner: planner, preferences: preferences, latestCatalog: catalog)
    }
}

protocol AppBootstrapProtocol: Sendable {
    func open() async throws -> AppServices
}

actor AppBootstrap: AppBootstrapProtocol {
    func open() async throws -> AppServices {
        let container = try await LocalStore.makeContainer()
        let plans = PlanRepository(container: container)
        let saved = try await plans.loadActivePlan()
        let catalog: RecipeCatalog
        do { catalog = try await CatalogService(allowDevelopment: true).loadCatalog() }
        catch CatalogError.expiredPrices {
            guard let saved else { throw CatalogError.expiredPrices }
            catalog = saved.catalog
        }
        let preferences = MealPreferenceRepository(container: container)
        #if DEBUG
        let planner = PlanService(menuProposer: GeminiMenuProposer())
        #else
        let planner = PlanService()
        #endif
        let changes = PlanChangeService(plans: plans, planner: planner, preferences: preferences, latestCatalog: catalog)
        return AppServices(catalog: catalog, profiles: ProfileRepository(container: container), plans: plans,
                           planner: planner, checklist: ChecklistRepository(container: container),
                           preferences: preferences, shopping: ShoppingService(plans: plans),
                           cooking: CookingService(plans: plans, changes: changes), timers: TimerService(plans: plans), pantry: PantryRepository(plans: plans, catalog: catalog), history: HistoryRepository(plans: plans), cycles: NextCycleService(plans: plans), changes: changes)
    }
}

@MainActor
@Observable
final class AppSession {
    private(set) var services: AppServices?
    private(set) var plan: WeeklyPlan?
    private(set) var draft: PlanningProfile?
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    private let bootstrap: any AppBootstrapProtocol

    init(bootstrap: any AppBootstrapProtocol = AppBootstrap()) { self.bootstrap = bootstrap }

    func load() async {
        guard services == nil else { await refreshPlan(); return }
        isLoading = true
        errorMessage = nil
        do {
            let opened = try await bootstrap.open()
            let saved = try await opened.plans.loadActivePlan()
            let draft = try await opened.profiles.loadProfile()
            try Task.checkCancellation()
            self.plan = saved
            self.draft = draft
            self.services = opened
        } catch is CancellationError {
            isLoading = false
            return
        } catch CatalogError.expiredPrices {
            errorMessage = "Development prices have expired. An updated catalog is needed to make a new estimate."
        } catch {
            errorMessage = "Your saved information could not be opened. Please retry. Your data has not been reset."
        }
        isLoading = false
    }

    func accept(_ plan: WeeklyPlan) {
        self.plan = plan
        draft = plan.profile
    }

    func rememberDraft(_ profile: PlanningProfile) { draft = profile }

    func refreshPlan() async {
        guard let services else { return }
        do {
            let updated = try await services.plans.loadActivePlan()
            if updated?.revision != plan?.revision { plan = updated; draft = updated?.profile }
            errorMessage = nil
        } catch is CancellationError { return }
        catch { errorMessage = "Your latest plan could not be loaded. Please retry." }
    }

    func reset() async throws {
        guard let services else { throw PersistenceError.openFailed }
        try await services.plans.resetActivePlan()
        plan = nil
        draft = nil
    }
}
