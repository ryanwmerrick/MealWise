import Combine
import Foundation

@MainActor
final class ShoppingViewModel: ObservableObject {
    @Published private(set) var trip: ShoppingTrip?
    @Published private(set) var substitutes: [ShoppingSubstitutionPreview] = []
    @Published private(set) var summaries: [ShoppingSummary] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWorking = false
    let planID: UUID
    private let service: any ShoppingServiceProtocol
    init(planID: UUID, service: any ShoppingServiceProtocol) { self.planID = planID; self.service = service }
    func load() async {
        guard !isWorking else { return }
        isWorking = true; defer { isWorking = false }
        do {
            let trip = try await service.openTrip(planID: planID)
            try Task.checkCancellation()
            self.trip = trip; errorMessage = nil
        } catch is CancellationError { return }
        catch { errorMessage = "Shopping could not be opened. Return to the current grocery list and retry." }
    }
    func loadHistory() async {
        do { summaries = try await service.history(planID: planID); errorMessage = nil }
        catch { errorMessage = "Shopping history could not be loaded. Please retry." }
    }
    func selectStore(_ store: GroceryPreference?) async {
        guard let trip, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            self.trip = try await service.selectStore(store, tripID: trip.id)
            errorMessage = nil
        } catch {
            errorMessage = "The store could not be saved. Reopen the current trip and retry."
        }
    }
    func toggle(itemID: UUID, wasChecked: Bool) async {
        guard let trip, !isWorking else { return }
        isWorking = true; defer { isWorking = false }
        do { self.trip = try await service.setChecked(itemID: itemID, checked: !wasChecked, tripID: trip.id); errorMessage = nil }
        catch { errorMessage = "Your purchase check could not be saved. Reopen the current trip and retry." }
    }
    func price(_ text: String, lineID: UUID) async -> Bool {
        guard let trip, !isWorking else { return false }
        let money: Money
        do { money = try Money.parse(text) }
        catch { errorMessage = "Enter a nonnegative dollar amount with up to two decimal places."; return false }
        isWorking = true; defer { isWorking = false }
        do {
            self.trip = try await service.updatePrice(itemID: lineID, actualPrice: money, tripID: trip.id)
            errorMessage = nil; return true
        } catch { errorMessage = "The price could not be saved. Reopen the current trip and retry."; return false }
    }
    func finish() async -> ShoppingSummary? {
        guard let trip, !isWorking else { return nil }
        isWorking = true; defer { isWorking = false }
        do { let summary = try await service.finishTrip(trip.id); errorMessage = nil; return summary }
        catch ShoppingError.noPurchases { errorMessage = "Check the items you purchased before finishing this trip."; return nil }
        catch { errorMessage = "This trip could not be finished. Reopen it from the current grocery list; your edits are saved."; return nil }
    }
    func findSubstitutes(lineID: UUID) async {
        guard let trip, !isWorking else { return }
        isWorking = true; substitutes = []; defer { isWorking = false }
        do { substitutes = try await service.cheaperSubstitutes(itemID: lineID, tripID: trip.id); errorMessage = nil }
        catch { errorMessage = "Package alternatives could not be checked. Your current trip is unchanged." }
    }
    func acceptSubstitute(_ option: ShoppingSubstitutionPreview) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true; defer { isWorking = false }
        do { trip = try await service.acceptSubstitute(option); substitutes = []; errorMessage = nil; return true }
        catch { errorMessage = "This package preview is out of date or could not be saved. Reopen it from your current trip."; return false }
    }
    var projected: Int64? { try? trip?.projectedMinorUnits }
}
