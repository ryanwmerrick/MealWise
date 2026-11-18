import Combine
import Foundation

@MainActor final class MealRatingViewModel: ObservableObject {
    @Published private(set) var rating: MealRating?
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    private let mealID: UUID
    private let repository: any MealPreferenceRepositoryProtocol
    init(mealID: UUID, repository: any MealPreferenceRepositoryProtocol) { self.mealID = mealID; self.repository = repository }
    func load() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do { rating = try await repository.loadRatings().first { $0.mealID == mealID }?.rating; errorMessage = nil }
        catch { errorMessage = "Your meal rating could not be loaded." }
    }
    func rate(_ value: MealRating) async {
        guard !isWorking else { return }
        isWorking = true; defer { isWorking = false }
        do { try await repository.rate(mealID: mealID, rating: value); rating = value; errorMessage = nil }
        catch { errorMessage = "Your rating could not be saved. The cooked meal remains recorded." }
    }
}
