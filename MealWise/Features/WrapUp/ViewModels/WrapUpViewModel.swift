import Combine
import Foundation

struct CarryoverDraft: Identifiable {
    let source: CarryoverSource
    var quantityText: String
    var storage: StorageKind?
    var hasExpiry: Bool
    var expiry: Date
    var available = false
    var id: String { source.id }
}

@MainActor
final class WrapUpViewModel: ObservableObject {
    @Published var drafts: [CarryoverDraft] = []
    @Published private(set) var report: WrapUpReport?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWorking = false
    private let planID: UUID
    private let services: AppServices
    init(planID: UUID, services: AppServices) { self.planID = planID; self.services = services }
    func load() async {
        do {
            guard let plan = try await services.plans.loadActivePlan(), plan.id == planID, plan.closedAt == nil else { throw PantryError.cycleClosed }
            let report = try WrapUpReport.make(plan: plan)
            self.report = report
            drafts = report.sources.map { CarryoverDraft(source: $0, quantityText: PantryQuantityInput.text(amount: $0.quantity, unit: $0.unit), storage: $0.storage, hasExpiry: $0.expiry != nil, expiry: $0.expiry ?? .now) }
            errorMessage = nil
        } catch { errorMessage = "This cycle could not be opened for wrap-up. Return to your current plan and retry." }
    }
    func confirm() async -> Bool {
        guard let report, !isWorking else { return false }
        isWorking = true; defer { isWorking = false }
        do {
            let lines = try drafts.filter(\.available).map { draft in
                let quantity = try PantryQuantityInput.parse(draft.quantityText, unit: draft.source.unit)
                guard quantity <= draft.source.quantity else { throw PantryError.invalidQuantity }
                let expiry = draft.hasExpiry ? Calendar.autoupdatingCurrent.dateInterval(of: .day, for: draft.expiry)?.end.addingTimeInterval(-0.001) : nil
                return CarryoverLine(sourceID: draft.id, quantity: quantity, storage: draft.storage, expiry: expiry, availabilityConfirmed: true)
            }
            try await services.pantry.confirmCarryover(CarryoverConfirmation(planID: planID, expectedRevision: report.plan.revision, items: lines))
            return true
        } catch PantryError.staleStock { errorMessage = "Your cycle or stock changed. Close wrap-up and review the latest quantities."; return false }
        catch { errorMessage = "Check confirmed quantities and storage details. Nothing was carried over; please retry."; return false }
    }
}
