import Foundation
import SwiftData

protocol HistoryRepositoryProtocol: Sendable {
    func loadCycles() async throws -> [CycleHistory]
    func loadArchives() async throws -> [PlanArchive]
}

actor HistoryRepository: HistoryRepositoryProtocol {
    private let plans: PlanRepository
    init(plans: PlanRepository) { self.plans = plans }
    func loadCycles() async throws -> [CycleHistory] { try await plans.cycleHistory() }
    func loadArchives() async throws -> [PlanArchive] { try await plans.loadArchivedPlans() }
}

extension PlanRepository {
    func cycleHistory() throws -> [CycleHistory] {
        let context = ModelContext(container)
        do {
            let histories = try context.fetch(FetchDescriptor<StoredDocument>()).filter { $0.key.hasPrefix("cycle-history-") }
                .map { try JSONDecoder().decode(CycleHistory.self, from: $0.payload) }
            for history in histories {
                try PlanValidation.validate(history.plan)
                guard history.plan.closedAt != nil else { throw PersistenceError.corruptData }
            }
            return histories.sorted { $0.completedAt > $1.completedAt }
        } catch { throw PersistenceError.corruptData }
    }
}
