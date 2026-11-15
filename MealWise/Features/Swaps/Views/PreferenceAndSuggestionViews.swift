import SwiftUI

struct ExcludedRecipesView: View {
    @StateObject private var viewModel: ExcludedRecipesViewModel
    let catalog: RecipeCatalog
    init(catalog: RecipeCatalog, preferences: any MealPreferenceRepositoryProtocol) {
        self.catalog = catalog
        _viewModel = StateObject(wrappedValue: ExcludedRecipesViewModel(preferences: preferences))
    }
    var body: some View {
        List {
            if viewModel.ids.isEmpty { Text("No recipes are excluded from future plans.") }
            ForEach(viewModel.ids.sorted(), id: \.self) { id in
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey(catalog.recipes.first { $0.id == id }?.title ?? "Unavailable recipe"))
                    Button("Allow again") { Task { await viewModel.allow(id) } }.frame(minHeight: 44)
                }
            }
            if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
        }.navigationTitle("Excluded recipes").task { await viewModel.load() }
    }
}

struct RemainderSuggestionView: View {
    @StateObject private var viewModel: RemainderSuggestionViewModel
    @State private var selected: RemainderSuggestion?
    let services: AppServices
    init(plan: WeeklyPlan, ingredientID: String, services: AppServices) {
        self.services = services
        _viewModel = StateObject(wrappedValue: RemainderSuggestionViewModel(plan: plan, ingredientID: ingredientID, services: services))
    }
    var body: some View {
        List {
            Text("These swaps use more of the selected ingredient without adding another package of it. All proposed carts fit the budget.")
            if viewModel.isLoading { ProgressView("Checking remainder swaps") }
            if !viewModel.isLoading && viewModel.options.isEmpty { Text("No suitable swap was found. Keep the current plan and review the remainder at wrap-up.") }
            ForEach(viewModel.options) { option in
                Button { selected = option } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(option.recipe.title)).font(.headline)
                        Text(option.meal.date, format: .dateTime.weekday().month().day())
                        if let plan = option.preview.proposedPlan { Text("New checkout: \(plan.totalMinorUnits.currency)") }
                    }.padding(.vertical, 8)
                }
            }
            if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
        }
        .navigationTitle("Use a remainder")
        .task { await viewModel.load() }
        .sheet(item: $selected) { option in
            ChangePreviewScreen(plan: viewModel.plan, change: .swap(mealID: option.meal.id, recipeID: option.recipe.id), services: services)
        }
    }
}

#Preview { RootView().environment(AppSession()) }
