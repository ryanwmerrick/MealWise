import SwiftUI

struct MealRatingView: View {
    @StateObject private var viewModel: MealRatingViewModel
    init(mealID: UUID, preferences: any MealPreferenceRepositoryProtocol) { _viewModel = StateObject(wrappedValue: MealRatingViewModel(mealID: mealID, repository: preferences)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Would you cook this again?").font(.headline)
            Button("Yes, save to Favorites", systemImage: viewModel.rating == .liked ? "hand.thumbsup.fill" : "hand.thumbsup") { Task { await viewModel.rate(.liked) } }
                .frame(minHeight: 44).accessibilityIdentifier("rating.liked").accessibilityAddTraits(viewModel.rating == .liked ? .isSelected : [])
            Button("Prefer other meals", systemImage: viewModel.rating == .disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown") { Task { await viewModel.rate(.disliked) } }
                .frame(minHeight: 44).accessibilityIdentifier("rating.disliked").accessibilityAddTraits(viewModel.rating == .disliked ? .isSelected : [])
            if viewModel.rating != nil { Text("Rating saved").font(.caption).accessibilityIdentifier("rating.saved") }
            if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
        }.buttonStyle(.borderless).disabled(viewModel.isWorking).task { await viewModel.load() }
    }
}

#Preview { RootView().environment(AppSession()) }
