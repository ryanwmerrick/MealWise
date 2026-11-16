import SwiftUI

struct CycleHistoryView: View {
    @StateObject private var viewModel: CycleHistoryViewModel
    let services: AppServices
    init(services: AppServices) {
        self.services = services; _viewModel = StateObject(wrappedValue: CycleHistoryViewModel(repository: services.history))
    }
    var body: some View {
        List {
            if viewModel.isLoading { ProgressView("Loading cycle history") }
            if !viewModel.isLoading && viewModel.cycles.isEmpty && viewModel.archives.isEmpty { Text("No completed or reset cycles are recorded.") }
            ForEach(viewModel.cycles) { cycle in
                NavigationLink { CycleSummaryView(plan: cycle.plan, completedAt: cycle.completedAt, confirmation: cycle.confirmation, services: services) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(cycle.completedAt, format: .dateTime.month().day().year())
                        Text("Cooked meals: \(cycle.plan.resources?.cookedMeals?.count ?? 0)")
                    }.padding(.vertical, 8)
                }.accessibilityIdentifier("history.cycle")
            }
            ForEach(viewModel.archives) { archive in
                NavigationLink { CycleSummaryView(plan: archive.plan, completedAt: archive.archivedAt, confirmation: nil, services: services) } label: {
                    VStack(alignment: .leading) { Text("Reset plan archive"); Text(archive.archivedAt, format: .dateTime.month().day().year()) }
                }
            }
            if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)); Button("Retry") { Task { await viewModel.load() } } }
        }.navigationTitle("Cycle history").task { await viewModel.load() }
    }
}

struct CycleSummaryView: View {
    let plan: WeeklyPlan
    let completedAt: Date
    let confirmation: CarryoverConfirmation?
    let services: AppServices
    var body: some View {
        List {
            Section("Recorded cycle") {
                Text(completedAt, format: .dateTime.month().day().year())
                LabeledContent("Planned budget", value: plan.profile.budgetMinorUnits.currency)
                LabeledContent("Known actual spending", value: (plan.resources?.knownActualMinorUnits ?? 0).currency)
                LabeledContent("Purchase lines missing actual prices", value: (plan.resources?.missingPriceCount ?? 0).formatted())
                LabeledContent("Cooked meals", value: (plan.resources?.cookedMeals?.count ?? 0).formatted())
                LabeledContent("Meals not recorded as cooked", value: (plan.meals.count - (plan.resources?.cookedMeals?.count ?? 0)).formatted())
                Text("Missing receipt prices remain unknown. Uncooked meals did not consume stock; this history is preserved.").font(.footnote)
                NavigationLink("Shopping receipts") { ShoppingHistoryView(planID: plan.id, service: services.shopping) }
            }
            if let confirmation {
                Section("Confirmed carryover") {
                    if confirmation.items.isEmpty { Text("No stock was confirmed for carryover.") }
                    ForEach(confirmation.items, id: \.sourceID) { line in
                        if let source = try? StockAccounting.sources(plan: plan).first(where: { $0.id == line.sourceID }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStringKey(plan.catalog.ingredients.first { $0.id == source.ingredientID }?.name ?? "Ingredient"))
                                Text(QuantityFormatting.display(amount: line.quantity, unit: source.unit))
                                if let expiry = line.expiry { Text(expiry, format: .dateTime.month().day().year()) }
                                else { Text("Label date unknown") }
                            }
                        }
                    }
                }
            }
            Section("Meals") {
                ForEach(plan.meals) { meal in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(meal.date, format: .dateTime.weekday().month().day())
                        Text(LocalizedStringKey(plan.catalog.recipes.first { $0.id == meal.recipeID }?.title ?? "Meal"))
                        Text(plan.cookedRecord(for: meal.id) == nil ? "Not recorded as cooked" : "Cooked")
                    }.padding(.vertical, 6)
                }
            }
        }.navigationTitle("Cycle summary").navigationBarTitleDisplayMode(.inline)
    }
}
