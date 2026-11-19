import Combine
import Foundation

@MainActor
final class NextWeekViewModel: ObservableObject {
    @Published private(set) var isLoading = true
    @Published private(set) var restoredDraft: PlanningProfile?
    @Published var selectedObservations: Set<String> = []
    @Published private(set) var observations: [ReceiptPriceObservation] = []
    @Published private(set) var stock: [PantryItem] = []
    @Published private(set) var errorMessage: String?
    let closedPlan: WeeklyPlan
    let services: AppServices
    private let clock: @Sendable () -> Date
    init(plan: WeeklyPlan, services: AppServices, clock: @escaping @Sendable () -> Date = { .now }) { closedPlan = plan; self.services = services; self.clock = clock }
    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            stock = try await services.pantry.loadItems().filter { $0.customName == nil }
            observations = ReceiptCatalog.observations(from: try await services.shopping.history(planID: closedPlan.id), catalog: services.catalog)
            if let draft = try await services.profiles.loadProfile(),
               let last = closedPlan.profile.days.max(), draft.days.allSatisfy({ $0 > last }) {
                try draft.validate(); restoredDraft = draft
            }
            errorMessage = nil
        } catch { errorMessage = "Next-week stock and receipt observations could not be loaded. Please retry." }
    }
    func reviewedCatalog() throws -> RecipeCatalog {
        try ReceiptCatalog.apply(observations.filter { selectedObservations.contains($0.id) }, to: services.catalog, at: clock())
    }
    var profile: PlanningProfile {
        var profile = restoredDraft ?? closedPlan.profile
        let calendar = Calendar.autoupdatingCurrent
        var weeks = restoredDraft == nil ? 1 : 0
        let first = profile.days.min() ?? clock()
        while let next = calendar.date(byAdding: .weekOfYear, value: weeks, to: first), next < calendar.startOfDay(for: clock()) { weeks += 1 }
        if weeks == 0 { return profile }
        profile.days = profile.days.compactMap { calendar.date(byAdding: .weekOfYear, value: weeks, to: $0) }.map { calendar.startOfDay(for: $0) }
        return profile
    }
}
