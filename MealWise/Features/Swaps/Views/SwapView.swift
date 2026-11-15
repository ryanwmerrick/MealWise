import SwiftUI

struct SwapView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SwapViewModel

    init(plan: WeeklyPlan, mealID: UUID, services: AppServices) {
        _viewModel = StateObject(wrappedValue: SwapViewModel(plan: plan, mealID: mealID, services: services))
    }

    var body: some View {
        NavigationStack {
            List {
                if let target = viewModel.target {
                    Section { Text(target.date, format: .dateTime.weekday().month().day()); Text(LocalizedStringKey(target.slot.title)) }
                }
                Toggle("Show over-budget comparisons", isOn: $viewModel.showOverBudget)
                if viewModel.isWorking { ProgressView("Pricing replacements") }
                ForEach(viewModel.visibleOptions) { option in
                    Button { viewModel.selectedID = option.id } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(option.recipe.title)).font(.headline)
                            if let plan = option.preview.proposedPlan { Text("New checkout: \(plan.totalMinorUnits.currency)") }
                            Text("Ingredients reused: \(option.preview.reusedIngredientCount)").font(.caption)
                            if option.preview.constraint == .overBudget { Text("Over budget — comparison only").font(.caption) }
                        }.padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(viewModel.selectedID == option.id ? .isSelected : [])
                    .accessibilityIdentifier("swap.option")
                }
                if !viewModel.isWorking && viewModel.visibleOptions.isEmpty {
                    Text("No suitable replacements are available with the current catalog and constraints.")
                }
                if let selected = viewModel.selected { ChangePreviewCard(preview: selected.preview) }
                if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
                if let notice = viewModel.notice { Text(LocalizedStringKey(notice)) }
                Section("Recipe preferences") {
                    Button("Exclude this recipe from future plans") { Task { await viewModel.excludeCurrent() } }.frame(minHeight: 44)
                }
            }
            .navigationTitle("Swap meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(viewModel.isWorking) } }
            .interactiveDismissDisabled(viewModel.isWorking)
            .safeAreaInset(edge: .bottom) {
                Button("Confirm swap") { Task { if let plan = await viewModel.accept() { session.accept(plan) } } }
                    .buttonStyle(MealWiseButtonStyle())
                    .disabled(viewModel.selected?.preview.constraint != .feasible || viewModel.isWorking)
                    .padding(20).background(DesignTokens.surface)
            }
            .task { await viewModel.load() }
        }
    }
}

#Preview { RootView().environment(AppSession()) }
