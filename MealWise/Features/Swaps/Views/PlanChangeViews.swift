import SwiftUI

struct ChangePreviewCard: View {
    let preview: PlanChangePreview

    var body: some View {
        let allocationReport = preview.proposedPlan.flatMap { try? IngredientAllocationService().allocate(plan: $0) }
        Section("Before and after") {
            LabeledContent("Current projection", value: preview.oldTotalMinorUnits.currency)
            if let plan = preview.proposedPlan {
                LabeledContent("New projection", value: plan.totalMinorUnits.currency)
                LabeledContent("New budget", value: plan.profile.budgetMinorUnits.currency)
                LabeledContent("Remaining", value: plan.remainingMinorUnits.currency)
                LabeledContent("Ingredients reused", value: preview.reusedIngredientCount.formatted())
            }
            Text(LocalizedStringKey(preview.constraint.message))
            if let plan = preview.proposedPlan {
                DisclosureGroup("Show proposed schedule") {
                    ForEach(plan.meals) { meal in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.date, format: .dateTime.weekday().month().day()).font(.caption)
                            Text(LocalizedStringKey(plan.catalog.recipes.first { $0.id == meal.recipeID }?.title ?? "Meal"))
                            Text(LocalizedStringKey(meal.slot.title)).font(.caption)
                            if let allocationReport {
                                let notes = allocationReport.reservations(after: meal)
                                if !notes.isEmpty {
                                    DisclosureGroup("Save for later meals") { ReservationNotes(notes: notes) }
                                        .accessibilityIdentifier("preview.reservations")
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }
        }
        if preview.proposedPlan != nil {
            Section("Cart and ingredient impact") {
                ForEach(preview.impacts.filter { $0.oldPackages != $0.newPackages || $0.oldRequired != $0.newRequired || $0.oldCost != $0.newCost }) { impact in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(impact.name)).font(.headline)
                        Text("Packages: \(impact.oldPackages) → \(impact.newPackages)")
                        Text("Checkout: \(impact.oldCost.currency) → \(impact.newCost.currency)")
                        Text("Planned use: \(QuantityFormatting.display(amount: impact.oldRequired, unit: impact.unit)) → \(QuantityFormatting.display(amount: impact.newRequired, unit: impact.unit))").font(.footnote)
                    }.padding(.vertical, 5)
                }
            }
        }
    }
}

struct ChangePreviewScreen: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlanChangeViewModel
    let change: PlanChange

    init(plan: WeeklyPlan, change: PlanChange, services: AppServices) {
        self.change = change
        _viewModel = StateObject(wrappedValue: PlanChangeViewModel(plan: plan, changes: services.changes))
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isWorking { ProgressView("Checking the complete cart") }
                if let preview = viewModel.preview { ChangePreviewCard(preview: preview) }
                if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
                if let preview = viewModel.preview {
                    Button("Accept change") { Task { if let plan = await viewModel.accept() { session.accept(plan) } } }
                        .disabled(preview.constraint != .feasible || viewModel.isWorking).frame(minHeight: 44)
                }
                Button("Keep current plan") { dismiss() }.frame(minHeight: 44).disabled(viewModel.isWorking)
                DevelopmentNotice()
            }
            .navigationTitle("Review change")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.prepare(change) }
            .interactiveDismissDisabled(viewModel.isWorking)
        }
    }
}

struct BudgetAdjustmentView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlanChangeViewModel
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .body) private var presetWidth = 72

    init(plan: WeeklyPlan, services: AppServices) {
        _viewModel = StateObject(wrappedValue: PlanChangeViewModel(plan: plan, changes: services.changes))
    }

    var body: some View {
        List {
            Section("New spending cap") {
                TextField("Weekly budget in dollars", text: $viewModel.budgetText).keyboardType(.decimalPad).focused($focused)
                    .accessibilityIdentifier("budget.adjustment")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: presetWidth))]) {
                    ForEach([40, 55, 70, 90], id: \.self) { value in
                        Button(Int64(value * 100).currency) { viewModel.budgetText = String(value) }
                            .buttonStyle(.bordered).frame(minHeight: 44).accessibilityIdentifier("adjust.preset.\(value)")
                    }
                }
                Button("Preview budget") { focused = false; Task { await viewModel.prepareBudget() } }
                    .disabled(viewModel.isWorking).frame(minHeight: 44)
            }
            if viewModel.isWorking { ProgressView("Re-optimizing your week") }
            if let preview = viewModel.preview {
                ChangePreviewCard(preview: preview)
                Section {
                    Button("Accept change") { Task { if let plan = await viewModel.accept() { session.accept(plan) } } }
                        .disabled(preview.constraint != .feasible || viewModel.isWorking).frame(minHeight: 44)
                }
            }
            if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
            Section { Button("Keep current plan") { dismiss() }.frame(minHeight: 44).disabled(viewModel.isWorking); DevelopmentNotice() }
        }
        .navigationTitle("Adjust budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } }
        .interactiveDismissDisabled(viewModel.isWorking)
    }
}

#Preview { RootView().environment(AppSession()) }
