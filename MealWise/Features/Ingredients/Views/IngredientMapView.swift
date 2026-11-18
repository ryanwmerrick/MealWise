import SwiftUI

struct IngredientMapView: View {
    @StateObject private var viewModel: IngredientViewModel
    @State private var reload = 0

    init(planID: UUID, plans: any PlanRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: IngredientViewModel(planID: planID, plans: plans))
    }

    var body: some View {
        Group {
            if let report = viewModel.report, let plan = viewModel.plan {
                List {
                    Section("Planned package use") {
                        LabeledContent("Fully allocated", value: report.items.filter { $0.status == .fullyUsed }.count.formatted())
                        LabeledContent("Shelf-stable carryover", value: report.items.filter { $0.status == .carryOver }.count.formatted())
                        LabeledContent("Needs attention", value: report.items.filter { $0.status == .needsAttention }.count.formatted())
                        ForecastNotice()
                    }
                    ForEach(report.items) { item in
                        NavigationLink(value: PlanRoute.ingredientDetail(planID: plan.id, ingredientID: item.id)) {
                            allocationRow(item)
                        }
                        .accessibilityIdentifier("ingredient.row")
                    }
                }
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Ingredient map unavailable", systemImage: "exclamationmark.triangle")
                } description: { Text(LocalizedStringKey(error)) } actions: {
                    Button("Retry") { reload += 1 }.frame(minHeight: 44)
                }
            } else { ProgressView("Checking package allocations") }
        }
        .navigationTitle("Ingredient map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: reload) { await viewModel.load() }
    }

    private func allocationRow(_ item: IngredientAllocation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(item.name)).font(.headline)
            Text(item.status.title).font(.subheadline).foregroundStyle(DesignTokens.action)
            Text("Purchased: \(QuantityFormatting.display(amount: item.purchasedQuantity, unit: item.unit)) · \(item.priceMinorUnits.currency)").font(.caption)
            Text("Expected remaining: \(QuantityFormatting.display(amount: item.remainingQuantity, unit: item.unit))").font(.caption)
            ProgressView(value: Double(item.usedQuantity), total: Double(item.purchasedQuantity)).tint(DesignTokens.action)
                .accessibilityHidden(true)
            Text("Planned meals using this item: \(item.allocations.count)").font(.caption)
        }.padding(.vertical, 8)
    }
}

struct ForecastNotice: View {
    var body: some View {
        Text("This is planned usage, not confirmed inventory. Storage and freshness are uncertain; check package handling instructions before keeping or reusing food.")
            .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
    }
}

extension AllocationStatus {
    var title: LocalizedStringKey {
        switch self { case .fullyUsed: "Fully allocated"; case .carryOver: "Shelf-stable carryover"; case .needsAttention: "Storage-sensitive remainder" }
    }
}

#Preview { RootView().environment(AppSession()) }
