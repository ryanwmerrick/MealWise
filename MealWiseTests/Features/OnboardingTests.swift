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

    @Test func previouslySelectedDatesRemainEditable() async throws {
        let profile = PlanningProfile.fixture
        let model = OnboardingViewModel(profile: profile, services: try await services(), now: profile.days[0].addingTimeInterval(10 * 86400))
        #expect(model.selectableDates.contains(profile.days[0]))
        model.toggleDay(profile.days[0])
        model.toggleDay(try #require(model.selectableDates.first))
        #expect(model.canContinue)
    }

    @Test func backPreservesAnswersAndSummaryEditReturnsToSummary() async throws {
        let services = try await services()
        let model = OnboardingViewModel(profile: .fixture, services: services)
        model.budgetText = "55"
        model.advance(); model.back()
        #expect(model.profile.budgetMinorUnits == 5500)
        model.edit(0); model.advance()
        #expect(model.step == 7)
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

    private func services(plans: (any PlanRepositoryProtocol)? = nil) async throws -> AppServices {
        let container = try await LocalStore.makeContainer(inMemory: true)
        let catalog = try await CatalogService(allowDevelopment: true, now: Date(timeIntervalSince1970: 1794528000)).loadCatalog()
        return AppServices(catalog: catalog, profiles: ProfileRepository(container: container),
                           plans: plans ?? PlanRepository(container: container), planner: PlanService(clock: { Date(timeIntervalSince1970: 1794528000) }), checklist: ChecklistRepository(container: container), preferences: MealPreferenceRepository(container: container), shopping: ShoppingService(container: container))
    }
}

private actor FailingPlanRepository: PlanRepositoryProtocol {
    func loadActivePlan() async throws -> WeeklyPlan? { nil }
    func saveActivePlan(_ plan: WeeklyPlan) async throws { throw PersistenceError.saveFailed }
    func resetActivePlan() async throws { throw PersistenceError.saveFailed }
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
    func commit(_ plan: WeeklyPlan, expectedRevision: UUID) async throws {}
}
