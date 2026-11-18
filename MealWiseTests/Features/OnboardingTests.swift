import Foundation
import Testing
@testable import MealWise

@MainActor
struct OnboardingTests {
    @Test func retryAfterRefreshFailureRecoversExistingSession() async throws {
        let repository = RefreshFailureRepository()
        let dependencies = try await services(plans: repository)
        let session = AppSession(bootstrap: FixedBootstrap(services: dependencies))
        await session.load()
        #expect(session.services != nil)
        await repository.failNextRead()
        await session.refreshPlan()
        #expect(session.errorMessage != nil)
        await session.load()
        #expect(session.errorMessage == nil)
        #expect(session.services != nil)
    }

    @Test func persistedDraftCanRestoreSameSession() async throws {
        let services = try await services()
        let model = OnboardingViewModel(profile: .fixture, services: services)
        model.budgetText = "55"
        let draft = await model.saveDraft()
        #expect(draft?.budgetMinorUnits == 5500)
        let session = AppSession()
        if let draft { session.rememberDraft(draft) }
        #expect(session.draft?.budgetMinorUnits == 5500)
    }

    @Test func nextWeekRestoresItsSavedAnswers() async throws {
        let dependencies = try await services()
        guard case .feasible(let plan) = try await dependencies.planner.generate(PlanRequest(profile: .fixture, catalog: dependencies.catalog)) else { throw PlanningError.invalidPlan }
        let closed = WeeklyPlan(id: plan.id, revision: plan.revision, profile: plan.profile, catalog: plan.catalog, meals: plan.meals, cart: plan.cart, totalMinorUnits: plan.totalMinorUnits, closedAt: plan.profile.days[0])
        var draft = plan.profile
        draft.days = draft.days.compactMap { Calendar.autoupdatingCurrent.date(byAdding: .weekOfYear, value: 1, to: $0) }
        draft.budgetMinorUnits = 5500
        try await dependencies.profiles.saveProfile(draft)
        let next = NextWeekViewModel(plan: closed, services: dependencies, clock: { Date(timeIntervalSince1970: 1794528000) })
        await next.load()
        #expect(next.profile == draft)
    }

    @Test func dateChoicesDoNotDuplicateSelectedLocalDays() async throws {
        let profile = PlanningProfile.fixture
        let model = OnboardingViewModel(profile: profile, services: try await services(), now: profile.days[0])
        let localDays = model.upcomingDates.map { Calendar.autoupdatingCurrent.startOfDay(for: $0) }
        #expect(Set(localDays).count == localDays.count)
    }

    @Test func recurringDaysUseMondayFirstAndMoveOlderDraftsForward() async throws {
        let profile = PlanningProfile.fixture
        let calendar = Calendar.current
        let savedDate = profile.days[0]
        let now = try #require(calendar.date(byAdding: .day, value: 10, to: savedDate))
        let model = OnboardingViewModel(profile: profile, services: try await services(), now: now)

        #expect(model.upcomingDates.map { calendar.component(.weekday, from: $0) } == [2, 3, 4, 5, 6, 7, 1])
        let weekday = calendar.component(.weekday, from: savedDate)
        let nextOccurrence = try #require(model.upcomingDates.first { calendar.component(.weekday, from: $0) == weekday })
        #expect(model.isDaySelected(nextOccurrence))
        model.edit(.schedule)
        model.advance()
        #expect(model.profile.days == [nextOccurrence])
    }

    @Test func restoringAnExistingWeekdayRetainsItsExactPlanDate() async throws {
        let dependencies = try await services()
        var profile = PlanningProfile.fixture
        let savedDate = Calendar.current.startOfDay(for: profile.days[0]).addingTimeInterval(3600)
        profile.days = [savedDate]
        guard case .feasible(let plan) = try await dependencies.planner.generate(PlanRequest(profile: profile, catalog: dependencies.catalog)) else {
            throw PlanningError.invalidPlan
        }
        let model = OnboardingViewModel(profile: profile, services: dependencies, basePlan: plan)
        let weekday = try #require(model.upcomingDates.first(where: model.isDaySelected))
        model.toggleDay(weekday)
        let available = try #require(model.upcomingDates.first { Calendar.current.isDate($0, inSameDayAs: savedDate) })
        model.toggleDay(available)
        #expect(model.profile.days == [savedDate])
    }

    @Test func detailedAllergiesKeepTheWholeGroupExcludedUntilLastSelectionIsRemoved() async throws {
        let model = OnboardingViewModel(profile: .fixture, services: try await services())
        model.toggleDetailedAllergy(.shrimp)
        model.toggleDetailedAllergy(.crab)
        #expect(model.profile.allergies == [.shellfish])
        #expect(model.profile.onboarding?.detailedAllergies == [.shrimp, .crab])
        model.toggleDetailedAllergy(.shrimp)
        #expect(model.profile.allergies == [.shellfish])
        model.toggleDetailedAllergy(.crab)
        #expect(model.profile.allergies.isEmpty)
    }

    @Test func planPresentationHonorsMinimumDuration() async throws {
        let model = OnboardingViewModel(profile: .fixture, services: try await services())
        let clock = ContinuousClock()
        let start = clock.now
        await model.build(minimumDisplay: .milliseconds(300))
        #expect(start.duration(to: clock.now) >= .milliseconds(300))
        #expect(model.preview != nil)
    }

    @Test func backPreservesAnswersAndSummaryEditReturnsToSummary() async throws {
        let services = try await services()
        let model = OnboardingViewModel(profile: .fixture, services: services)
        model.budgetText = "55"
        model.advance(); model.back()
        #expect(model.profile.budgetMinorUnits == 5500)
        model.edit(.budget); model.advance()
        #expect(model.step == .summary)
    }

    @Test func failedSaveKeepsPreviewForRetry() async throws {
        let services = try await services(plans: FailingPlanRepository())
        let model = OnboardingViewModel(profile: .fixture, services: services)
        await model.build()
        #expect(model.preview != nil)
        #expect(await model.acceptPreview() == nil)
        #expect(model.preview != nil)
        #expect(model.errorMessage != nil)
    }

    @Test func invalidBudgetCannotBuild() async throws {
        let model = OnboardingViewModel(profile: .fixture, services: try await services())
        model.budgetText = "2.555"
        #expect(!model.canContinue)
        await model.build()
        #expect(model.preview == nil)
    }

    @Test func infeasibleFavoritePinHasAnExplicitExplanation() async throws {
        let services = try await services()
        var profile = PlanningProfile.fixture; profile.budgetMinorUnits = 100
        try await services.preferences.setFavorite(recipeID: "spinach-bean-pasta", favorite: true)
        try await services.preferences.savePin(RecipePin(recipeID: "spinach-bean-pasta", date: profile.days[0], slot: .dinner))
        let model = OnboardingViewModel(profile: profile, services: services)
        await model.build()
        #expect(model.preview == nil)
        #expect(model.errorMessage?.contains("pinned favorites") == true)
    }

    @Test(arguments: [false, true])
    func lateRefreshCannotUndoResetOrAcceptedPlan(acceptNew: Bool) async throws {
        let repository = HeldRefreshRepository()
        let dependencies = try await services(plans: repository)
        let session = AppSession(bootstrap: FixedBootstrap(services: dependencies))
        await session.load()
        guard case .feasible(let original) = try await dependencies.planner.generate(PlanRequest(profile: .fixture, catalog: dependencies.catalog)) else { throw PlanningError.invalidPlan }
        try await repository.saveActivePlan(original); session.accept(original)
        await repository.holdNextRead()
        let refresh = Task { await session.refreshPlan() }
        await repository.waitUntilHeld()
        let expected: WeeklyPlan?
        if acceptNew {
            let updated = WeeklyPlan(id: original.id, revision: UUID(), profile: original.profile, catalog: original.catalog,
                meals: original.meals, cart: original.cart, totalMinorUnits: original.totalMinorUnits, pricedAt: original.pricedAt)
            try await repository.saveActivePlan(updated); session.accept(updated); expected = updated
        } else { try await session.reset(); expected = nil }
        await repository.releaseRead()
        await refresh.value
        #expect(session.plan == expected)
    }

    private func services(plans: (any PlanRepositoryProtocol)? = nil) async throws -> AppServices {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        let localPlans = PlanRepository(container: container)
        let changes = PlanChangeService(plans: localPlans, planner: PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }), preferences: MealPreferenceRepository(container: container), clock: { Date(timeIntervalSince1970: 1794528000) })
        return AppServices(catalog: catalog, profiles: ProfileRepository(container: container),
                           plans: plans ?? localPlans, planner: PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }), checklist: ChecklistRepository(container: container), preferences: MealPreferenceRepository(container: container), shopping: ShoppingService(plans: localPlans), cooking: CookingService(plans: localPlans, changes: changes), timers: TimerService(plans: localPlans), pantry: PantryRepository(plans: localPlans, catalog: catalog), history: HistoryRepository(plans: localPlans), cycles: NextCycleService(plans: localPlans))
    }
}

private actor FailingPlanRepository: PlanRepositoryProtocol {
    func loadActivePlan() async throws -> WeeklyPlan? { nil }
    func saveActivePlan(_ plan: WeeklyPlan) async throws { throw PersistenceError.saveFailed }
    func resetActivePlan() async throws { throw PersistenceError.saveFailed }
    func eraseLocalData() async throws { throw PersistenceError.saveFailed }
    func commit(_ plan: WeeklyPlan, expectedRevision: UUID) async throws { throw PersistenceError.saveFailed }
}

private struct FixedBootstrap: AppBootstrapProtocol {
    let services: AppServices
    func open() async throws -> AppServices { services }
}
private actor RefreshFailureRepository: PlanRepositoryProtocol {
    private var shouldFail = false
    func failNextRead() { shouldFail = true }
    func loadActivePlan() async throws -> WeeklyPlan? {
        if shouldFail { shouldFail = false; throw PersistenceError.readFailed }
        return nil
    }
    func saveActivePlan(_ plan: WeeklyPlan) async throws {}
    func resetActivePlan() async throws {}
    func eraseLocalData() async throws {}
    func commit(_ plan: WeeklyPlan, expectedRevision: UUID) async throws {}
}

private actor HeldRefreshRepository: PlanRepositoryProtocol {
    private var plan: WeeklyPlan?
    private var hold = false
    private var heldPlan: WeeklyPlan?
    private var continuation: CheckedContinuation<WeeklyPlan?, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    func holdNextRead() { hold = true }
    func waitUntilHeld() async { if continuation == nil { await withCheckedContinuation { observer = $0 } } }
    func releaseRead() { continuation?.resume(returning: heldPlan); continuation = nil }
    func loadActivePlan() async throws -> WeeklyPlan? {
        guard hold else { return plan }
        hold = false; heldPlan = plan
        return await withCheckedContinuation { continuation = $0; observer?.resume(); observer = nil }
    }
    func saveActivePlan(_ plan: WeeklyPlan) async throws { self.plan = plan }
    func resetActivePlan() async throws { plan = nil }
    func eraseLocalData() async throws { plan = nil }
    func commit(_ plan: WeeklyPlan, expectedRevision: UUID) async throws { self.plan = plan }
}
