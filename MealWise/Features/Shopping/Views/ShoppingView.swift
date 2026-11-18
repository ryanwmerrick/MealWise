import SwiftUI

struct ShoppingView: View {
    @Environment(AppSession.self) private var session
    @StateObject private var viewModel: ShoppingViewModel
    @State private var priceLine: ShoppingLine?
    @State private var substituteLine: ShoppingLine?
    @State private var showFinish = false
    @State private var summary: ShoppingSummary?
    init(planID: UUID, service: any ShoppingServiceProtocol) {
        _viewModel = StateObject(wrappedValue: ShoppingViewModel(planID: planID, service: service))
    }
    var body: some View {
        List {
            if let trip = viewModel.trip {
                Section("Trip spending") {
                    LabeledContent("Known actual this trip", value: viewModel.actual?.currency ?? String(localized: "Unavailable"))
                    LabeledContent("Projected full cycle", value: viewModel.projected?.currency ?? String(localized: "Unavailable"))
                    LabeledContent("Budget", value: trip.budgetMinorUnits.currency)
                    Text("\(trip.lines.filter(\.checked).count) of \(trip.lines.count) items checked for purchase")
                    Text("The projection includes unchecked items. Missing prices use sample estimates.").font(.footnote)
                    if let projected = viewModel.projected, projected > trip.budgetMinorUnits {
                        Text("Over budget by \((projected - trip.budgetMinorUnits).currency). Real spending will remain in your history.").foregroundStyle(DesignTokens.action)
                    }
                    if trip.priorSpendingMinorUnits > 0 {
                        LabeledContent("Earlier purchases, with estimates for missing prices", value: trip.priorSpendingMinorUnits.currency)
                    }
                }
                if trip.lines.isEmpty { Text("No additional packages are needed for this plan.") }
                ForEach(trip.lines) { line in
                    Section {
                        Button { Task { await viewModel.toggle(line) } } label: {
                            Label { Text(LocalizedStringKey(line.name)) } icon: { Image(systemName: line.checked ? "checkmark.square.fill" : "square") }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.accessibilityAddTraits(line.checked ? .isSelected : []).accessibilityIdentifier("shopping.check")
                        Text("\(line.packageCount) packages · \(QuantityFormatting.display(amount: line.packageQuantity, unit: line.unit)) each")
                        LabeledContent("Estimated line total", value: line.estimatedMinorUnits.currency)
                        if let actual = line.actualMinorUnits { LabeledContent("Entered actual line total", value: actual.currency) }
                        else { Text("Actual price not entered") }
                        Button("Edit actual price") { priceLine = line }.frame(minHeight: 44).accessibilityIdentifier("shopping.price")
                        Button("Find cheaper package") { substituteLine = line }.frame(minHeight: 44)
                    }
                }
                Section {
                    Button("Finish trip") { showFinish = true }.disabled(!trip.lines.contains(where: \.checked))
                        .frame(minHeight: 44)
                    Text("Only checked items become purchased stock. Unchecked items stay on the next shopping list. Missing receipt prices remain explicitly unknown.").font(.footnote)
                }
            }
            if viewModel.isWorking { ProgressView("Saving shopping") }
            if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)); Button("Reload trip") { Task { await viewModel.load() } } }
        }
        .navigationTitle("Shopping")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .disabled(viewModel.isWorking)
        .sheet(item: $priceLine) { line in ShoppingPriceView(line: line, viewModel: viewModel) }
        .sheet(item: $substituteLine) { line in ShoppingSubstituteView(line: line, viewModel: viewModel) }
        .confirmationDialog("Finish with only these purchased items?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Record purchased items") {
                Task {
                    if let result = await viewModel.finish() {
                        // Keep this screen stable while showing the receipt; returning refreshes the root plan.
                        summary = result
                    }
                }
            }
        } message: { Text("Missing actual prices remain unknown. Tax, deposits and fees are excluded unless you include them in your entered line totals.") }
        .navigationDestination(item: $summary) { result in ShoppingSummaryView(summary: result) }
    }
}

private struct ShoppingPriceView: View {
    @Environment(\.dismiss) private var dismiss
    let line: ShoppingLine
    @ObservedObject var viewModel: ShoppingViewModel
    @State private var text = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(LocalizedStringKey(line.name)).font(.headline)
                    Text("Enter the total for all \(line.packageCount) packages of this item, in USD.")
                    TextField("Actual line total", text: $text).keyboardType(.decimalPad).accessibilityIdentifier("shopping.actual")
                    if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
                }
                Button("Save price") { Task { if await viewModel.price(text, lineID: line.id) { dismiss() } } }
                    .disabled(viewModel.isWorking).frame(minHeight: 44)
                Text("This records your receipt observation for this package and store. It does not rewrite the catalog estimate.")
            }.navigationTitle("Actual price")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(viewModel.isWorking) } }
        }.interactiveDismissDisabled(viewModel.isWorking)
    }
}

extension ShoppingSummary: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.trip == rhs.trip }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ShoppingSummaryView: View {
    let summary: ShoppingSummary
    var body: some View {
        List {
            Section("Recorded purchases") {
                LabeledContent("Known actual spending", value: (try? summary.knownActualMinorUnits)?.currency ?? String(localized: "Unavailable")).accessibilityIdentifier("shopping.summary.actual")
                LabeledContent("Purchased items", value: summary.purchasedCount.formatted())
                LabeledContent("Purchased items missing actual prices", value: summary.missingPriceCount.formatted())
                LabeledContent("Unpurchased items", value: summary.unpurchasedCount.formatted())
                LabeledContent("Cycle budget at finish", value: summary.trip.budgetMinorUnits.currency)
                if let projected = try? summary.trip.projectedMinorUnits {
                    LabeledContent("Projected cycle at finish", value: projected.currency)
                }
                if summary.missingPriceCount > 0 { Text("This is an incomplete receipt. Missing prices remain estimates in cycle projections.") }
                if summary.unpurchasedCount > 0 { Text("This was a partial trip. Unpurchased requirements remain on your grocery list.") }
                if let projected = try? summary.trip.projectedMinorUnits, projected > summary.trip.budgetMinorUnits {
                    Text("The projected cycle exceeds its budget. Purchases and actual overspend remain recorded.")
                }
                if let date = summary.trip.finishedAt { Text(date, format: .dateTime.month().day().year().hour().minute()) }
            }
            ForEach(summary.trip.lines.filter(\.checked)) { line in
                Section(LocalizedStringKey(line.name)) {
                    Text("\(line.packageCount) packages purchased")
                    LabeledContent("Dated estimate", value: line.estimatedMinorUnits.currency)
                    if let actual = line.actualMinorUnits { LabeledContent("Recorded actual", value: actual.currency) }
                    else { Text("Actual price unknown") }
                }
            }
            Section { Text("Receipt observations are retained with this package, quantity and store for review in later plans. Tax, deposits and fees are excluded unless entered.") }
        }.navigationTitle("Trip summary").navigationBarTitleDisplayMode(.inline)
    }
}

struct ShoppingHistoryView: View {
    @StateObject private var viewModel: ShoppingViewModel
    init(planID: UUID, service: any ShoppingServiceProtocol) {
        _viewModel = StateObject(wrappedValue: ShoppingViewModel(planID: planID, service: service))
    }
    var body: some View {
        List {
            if viewModel.summaries.isEmpty { Text("No trips have been finished for this plan.") }
            ForEach(viewModel.summaries) { summary in
                NavigationLink { ShoppingSummaryView(summary: summary) } label: {
                    VStack(alignment: .leading) {
                        if let date = summary.trip.finishedAt { Text(date, format: .dateTime.month().day().hour().minute()) }
                        Text("\(summary.purchasedCount) purchased · \(summary.missingPriceCount) missing prices")
                    }.padding(.vertical, 8)
                }.accessibilityIdentifier("shopping.history")
            }
            if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
        }.navigationTitle("Shopping history").task { await viewModel.loadHistory() }
    }
}

#Preview { RootView().environment(AppSession()) }

private struct ShoppingSubstituteView: View {
    @Environment(\.dismiss) private var dismiss
    let line: ShoppingLine
    @ObservedObject var viewModel: ShoppingViewModel
    @State private var selected: ShoppingSubstitutionPreview?
    var body: some View {
        NavigationStack {
            List {
                Text("Compare packages of the same ingredient. Required food quantities and allergy requirements stay unchanged.")
                if viewModel.isWorking { ProgressView("Checking package alternatives") }
                if !viewModel.isWorking && viewModel.substitutes.isEmpty {
                    Text("No catalog-backed cheaper package fits this complete cart. Keep your current choice or review your budget.")
                }
                ForEach(viewModel.substitutes) { option in
                    Button { selected = option } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(line.name)).font(.headline)
                            Text("Package: \(QuantityFormatting.display(amount: option.offer.packageQuantity, unit: option.offer.unit))")
                            Text("Projected cycle: \(option.projectedMinorUnits.currency)")
                            Text("Price date: \(option.offer.priceDate)").font(.caption)
                        }.padding(.vertical, 8)
                    }
                }
                if let selected {
                    ChangePreviewCard(preview: selected.preview)
                    Text("The shopping projection above includes other entered receipt prices. This replacement resets only this item's check and actual price; confirm the replacement package before purchasing.")
                    Button("Use this package") { Task { if await viewModel.acceptSubstitute(selected) { dismiss() } } }
                        .disabled(viewModel.isWorking).frame(minHeight: 44)
                }
                if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
            }.navigationTitle("Cheaper packages")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Keep current package") { dismiss() }.disabled(viewModel.isWorking) } }
                .task { await viewModel.findSubstitutes(lineID: line.id) }
        }.interactiveDismissDisabled(viewModel.isWorking)
    }
}
