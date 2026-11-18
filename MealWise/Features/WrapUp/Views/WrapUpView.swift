import SwiftUI

struct WrapUpView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WrapUpViewModel
    @State private var confirming = false
    init(planID: UUID, services: AppServices) { _viewModel = StateObject(wrappedValue: WrapUpViewModel(planID: planID, services: services)) }
    var body: some View {
        NavigationStack {
            Form {
                if let report = viewModel.report {
                    Section("Cycle totals") {
                        LabeledContent("Planned budget", value: report.plan.profile.budgetMinorUnits.currency)
                        LabeledContent("Known actual spending", value: report.knownActualMinorUnits.currency)
                        LabeledContent("Purchase lines missing actual prices", value: report.missingPriceCount.formatted())
                        LabeledContent("Cooked meals", value: (report.plan.resources?.cookedMeals?.count ?? 0).formatted())
                        Text("Uncooked meals have not consumed ingredients. Count actual stock and confirm only what you have checked.").font(.footnote)
                    }
                    DisclosureGroup("Original leftover forecast") {
                        ForEach(report.forecast.items) { item in
                            LabeledContent { Text(QuantityFormatting.display(amount: item.remainingQuantity, unit: item.unit)) } label: { Text(LocalizedStringKey(item.name)) }
                        }
                        Text("This forecast assumed all planned meals would be cooked. It is separate from recorded stock and your confirmed quantities.").font(.footnote)
                    }
                    if viewModel.drafts.isEmpty { Text("No recorded stock remains. You can finish without adding anything to Pantry.") }
                    ForEach($viewModel.drafts) { $draft in
                        Section(LocalizedStringKey(report.plan.catalog.ingredients.first { $0.id == draft.source.ingredientID }?.name ?? "Ingredient")) {
                            Text("Recorded stock remaining: \(QuantityFormatting.display(amount: draft.source.quantity, unit: draft.source.unit))")
                            Text(draft.source.pantryItemID == nil ? "Purchased this cycle" : "Previously reserved pantry stock").font(.caption)
                            TextField("Confirmed quantity", text: $draft.quantityText).keyboardType(.decimalPad).accessibilityIdentifier("wrap.quantity")
                            Text("Quantity unit: \(PantryQuantityInput.symbol(unit: draft.source.unit))")
                            StorageFields(storage: $draft.storage, hasExpiry: $draft.hasExpiry, expiry: $draft.expiry)
                            Toggle("I have checked this stock for carryover", isOn: $draft.available).accessibilityIdentifier("wrap.available")
                        }
                    }
                }
                if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
            }.disabled(viewModel.isWorking)
                .navigationTitle("Wrap up your cycle")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(viewModel.isWorking) } }
                .safeAreaInset(edge: .bottom) {
                    Button("Confirm carryover") { confirming = true }.buttonStyle(MealWiseButtonStyle()).padding(20)
                        .background(DesignTokens.surface).disabled(viewModel.report == nil || viewModel.isWorking)
                }
                .confirmationDialog("Finish this cycle?", isPresented: $confirming, titleVisibility: .visible) {
                    Button("Finish cycle") { Task { if await viewModel.confirm() { await session.refreshPlan() } } }
                } message: { Text("Only checked sources enter Pantry. The cycle closes, remaining meal allocations end, and purchases and cooked history are preserved.") }
                .task { await viewModel.load() }
        }.interactiveDismissDisabled(viewModel.isWorking)
    }
}
