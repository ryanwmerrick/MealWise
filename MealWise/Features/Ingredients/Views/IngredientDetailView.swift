import SwiftUI

struct IngredientDetailView: View {
    let item: IngredientAllocation
    let planID: UUID

    var body: some View {
        List {
            Section {
                Text(LocalizedStringKey(item.name)).font(.title2.bold())
                LabeledContent("Purchased", value: QuantityFormatting.display(amount: item.purchasedQuantity, unit: item.unit))
                LabeledContent("Allocated", value: QuantityFormatting.display(amount: item.usedQuantity, unit: item.unit))
                LabeledContent("Expected remaining", value: QuantityFormatting.display(amount: item.remainingQuantity, unit: item.unit))
                LabeledContent("Package checkout", value: item.priceMinorUnits.currency)
                Text(item.status.title).foregroundStyle(DesignTokens.action)
                ForecastNotice()
            }
            Section("Planned use") {
                ForEach(item.allocations) { allocation in
                    NavigationLink(value: PlanRoute.meal(planID: planID, mealID: allocation.mealID)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(allocation.date, format: .dateTime.weekday().month().day()).font(.caption)
                            Text(LocalizedStringKey(allocation.recipeTitle)).font(.headline)
                            Text("\(String(localized: String.LocalizationValue(allocation.slot.title))) · \(QuantityFormatting.display(amount: allocation.quantity, unit: item.unit))")
                        }.padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("allocation.meal")
                }
            }
            if item.remainingQuantity > 0 {
                Section("What to do with the remainder") {
                    NavigationLink("Find a meal using this remainder", value: PlanRoute.remainderSuggestions(planID: planID, ingredientID: item.id))
                    if item.storage == .shelfStable {
                        Text("Check the package storage instructions. At wrap-up, confirm what remains before carrying it into the next plan.")
                    } else {
                        Text("This remainder needs a storage check. Consider using it in another meal, following the package guidance; no shelf-life duration is assumed.")
                    }
                }
            }
        }
        .navigationTitle("Ingredient details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview { RootView().environment(AppSession()) }

struct IngredientDetailScreen: View {
    @StateObject private var viewModel: IngredientViewModel
    let ingredientID: String

    init(planID: UUID, ingredientID: String, plans: any PlanRepositoryProtocol) {
        self.ingredientID = ingredientID
        _viewModel = StateObject(wrappedValue: IngredientViewModel(planID: planID, plans: plans))
    }

    var body: some View {
        Group {
            if let report = viewModel.report, let plan = viewModel.plan,
               let item = report.items.first(where: { $0.id == ingredientID }) {
                IngredientDetailView(item: item, planID: plan.id)
            } else if viewModel.report != nil || viewModel.errorMessage != nil {
                ContentUnavailableView("Ingredient unavailable", systemImage: "exclamationmark.triangle",
                                       description: Text("Return to your current ingredient map."))
            } else { ProgressView("Opening ingredient") }
        }.task { await viewModel.load() }
    }
}
