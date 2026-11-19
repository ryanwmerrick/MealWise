import SwiftUI

struct ShoppingView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ShoppingViewModel
    @State private var priceLine: ShoppingLine?
    @State private var substituteLine: ShoppingLine?
    @State private var showFinish = false

    let onFinish: (ShoppingSummary) -> Void

    init(planID: UUID, service: any ShoppingServiceProtocol, onFinish: @escaping (ShoppingSummary) -> Void) {
        _viewModel = StateObject(wrappedValue: ShoppingViewModel(planID: planID, service: service))
        self.onFinish = onFinish
    }

    var body: some View {
        List {
            if let trip = viewModel.trip {
                if trip.lines.isEmpty && trip.addedItems.isEmpty {
                    Text("No additional packages are needed for this plan.").mealWiseListRows()
                }
                if !trip.addedItems.isEmpty {
                    Section("Added by you") {
                        ForEach(trip.addedItems) { item in
                            purchaseCheck(itemID: item.id, checked: item.checked) {
                                ManualGroceryItemLabel(item: item)
                            }
                            .disabled(viewModel.isWorking)
                            .accessibilityIdentifier("shopping.manualCheck")
                        }
                    }.mealWiseListRows()
                }
                Section {
                    ForEach(trip.lines, content: shoppingRow)
                }.mealWiseListRows()
            }
            if viewModel.isWorking && viewModel.trip == nil {
                ProgressView("Opening shopping").mealWiseListRows()
            }
            if let error = viewModel.errorMessage {
                Section {
                    Text(LocalizedStringKey(error))
                    Button("Reload trip") { Task { await viewModel.load() } }
                }.mealWiseListRows()
            }
        }
        .contentMargins(.top, 8, for: .scrollContent)
        .mealWiseListStyle()
        .navigationTitle("Shopping")
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Minimize shopping", systemImage: "chevron.down") { dismiss() }
                    .labelStyle(.iconOnly)
                    .disabled(viewModel.isWorking)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let trip = viewModel.trip { shoppingHeader(trip) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let trip = viewModel.trip {
                Button("Finish trip") { showFinish = true }
                    .buttonStyle(MealWiseButtonStyle())
                    .disabled(viewModel.isWorking || !trip.hasCheckedItems)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(DesignTokens.surface)
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $priceLine) { line in ShoppingPriceView(line: line, viewModel: viewModel) }
        .sheet(item: $substituteLine) { line in ShoppingSubstituteView(line: line, viewModel: viewModel) }
        .confirmationDialog("Finish with only these purchased items?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Record purchased items") {
                Task {
                    if let result = await viewModel.finish() {
                        onFinish(result)
                        await session.refreshPlan()
                    }
                }
            }
        } message: {
            Text("Only checked items are recorded as purchased. Unchecked items stay on your grocery list.")
        }
    }

    private func shoppingHeader(_ trip: ShoppingTrip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            storeMenu(selection: trip.selectedStore)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { tripMetrics(trip) }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 6) { tripMetrics(trip) }
            }
            if let projected = viewModel.projected, projected > trip.budgetMinorUnits {
                Text("Over budget by \((projected - trip.budgetMinorUnits).currency)")
                    .font(.caption).foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(DesignTokens.surface)
    }

    @ViewBuilder
    private func tripMetrics(_ trip: ShoppingTrip) -> some View {
        metric("checklist") {
            Text("\(trip.itemsLeft) items left")
                .accessibilityIdentifier("shopping.itemsLeft")
        }
        if let startedAt = trip.startedAt {
            metric("timer") {
                Text(startedAt, style: .timer).monospacedDigit()
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(Text(startedAt, style: .timer))
                    .accessibilityIdentifier("shopping.elapsed")
            }
        }
        if let projected = viewModel.projected {
            metric("dollarsign.circle") {
                Text(projected.currency).monospacedDigit()
                    .accessibilityLabel(Text("Estimated weekly cost \(projected.currency)"))
            }
        }
    }

    private func metric(_ symbol: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(DesignTokens.action)
                .accessibilityHidden(true)
            content()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(DesignTokens.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignTokens.card, in: Capsule())
    }

    private func storeMenu(selection: GroceryPreference?) -> some View {
        Menu {
            if selection != nil {
                Button("Clear store selection") { Task { await viewModel.selectStore(nil) } }
            }
            ForEach(GroceryPreference.allCases, id: \.self) { store in
                Button { Task { await viewModel.selectStore(store) } } label: {
                    if selection == store {
                        Label(LocalizedStringKey(store.label), systemImage: "checkmark")
                    } else {
                        Text(LocalizedStringKey(store.label))
                    }
                }
            }
        } label: {
            Label(selection.map { LocalizedStringKey($0.label) } ?? "Choose store", systemImage: "storefront")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier("shopping.store")
        .disabled(viewModel.isWorking)
    }

    private func shoppingRow(_ line: ShoppingLine) -> some View {
        HStack(spacing: 4) {
            purchaseCheck(itemID: line.id, checked: line.checked) {
                GroceryItemLabel(name: line.name, packages: line.packageCount,
                                 packageSize: QuantityFormatting.display(amount: line.packageQuantity, unit: line.unit),
                                 costMinorUnits: line.actualMinorUnits ?? line.estimatedMinorUnits,
                                 showsActualPrice: line.actualMinorUnits != nil)
            }
            .accessibilityIdentifier("shopping.check")
            Menu {
                Button("Edit price", systemImage: "tag") { priceLine = line }
                    .accessibilityIdentifier("shopping.price")
                Button("Swap package", systemImage: "arrow.left.arrow.right") { substituteLine = line }
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Edit \(String(localized: String.LocalizationValue(line.name)))"))
            .accessibilityIdentifier("shopping.edit")
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.isWorking)
    }

    private func purchaseCheck<Content: View>(itemID: UUID, checked: Bool, @ViewBuilder content: () -> Content) -> some View {
        Button { Task { await viewModel.toggle(itemID: itemID, wasChecked: checked) } } label: {
            HStack(spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(DesignTokens.action)
                    .accessibilityHidden(true)
                content()
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}

private struct ShoppingPriceView: View {
    @Environment(\.dismiss) private var dismiss
    let line: ShoppingLine
    @ObservedObject var viewModel: ShoppingViewModel
    @State private var text: String

    init(line: ShoppingLine, viewModel: ShoppingViewModel) {
        self.line = line
        self.viewModel = viewModel
        _text = State(initialValue: line.actualMinorUnits.map { (Decimal($0) / 100).description } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(LocalizedStringKey(line.name)).font(.headline)
                    Text("Enter the total for all \(line.packageCount) packages of this item, in USD.")
                    TextField("Actual line total", text: $text).keyboardType(.decimalPad).accessibilityIdentifier("shopping.actual")
                    if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
                }.mealWiseListRows()
                Section {
                    Button("Save price") { Task { if await viewModel.price(text, lineID: line.id) { dismiss() } } }
                        .buttonStyle(MealWiseButtonStyle()).disabled(viewModel.isWorking)
                } footer: {
                    Text("This records your receipt observation for this package and store. It does not rewrite the catalog estimate.")
                }.mealWiseListRows()
            }.mealWiseListStyle()
                .navigationTitle("Actual price")
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
                if let store = summary.trip.selectedStore {
                    LabeledContent("Store") { Text(LocalizedStringKey(store.label)) }
                }
                LabeledContent("Known actual spending", value: (try? summary.knownActualMinorUnits)?.currency ?? String(localized: "Unavailable")).accessibilityIdentifier("shopping.summary.actual")
                LabeledContent("Purchased items", value: summary.purchasedCount.formatted())
                LabeledContent("Purchased items missing actual prices", value: summary.missingPriceCount.formatted())
                LabeledContent("Unpurchased items", value: summary.unpurchasedCount.formatted())
                LabeledContent("Cycle budget at finish", value: summary.trip.budgetMinorUnits.currency)
                if let projected = try? summary.trip.projectedMinorUnits {
                    LabeledContent("Projected cycle at finish", value: projected.currency)
                }
                if summary.missingPriceCount > 0 { Text("Some purchases have no recorded price.") }
                if summary.unpurchasedCount > 0 { Text("This was a partial trip. Unpurchased requirements remain on your grocery list.") }
                if let projected = try? summary.trip.projectedMinorUnits, projected > summary.trip.budgetMinorUnits {
                    Text("The projected cycle exceeds its budget. Purchases and actual overspend remain recorded.")
                }
                if let date = summary.trip.finishedAt { Text(date, format: .dateTime.month().day().year().hour().minute()) }
            }.mealWiseListRows()
            ForEach(summary.trip.lines.filter(\.checked)) { line in
                Section(LocalizedStringKey(line.name)) {
                    Text("\(line.packageCount) packages purchased")
                    LabeledContent("Dated estimate", value: line.estimatedMinorUnits.currency)
                    if let actual = line.actualMinorUnits { LabeledContent("Recorded actual", value: actual.currency) }
                    else { Text("Actual price unknown") }
                }.mealWiseListRows()
            }
            let addedPurchases = summary.trip.addedItems.filter(\.checked)
            if !addedPurchases.isEmpty {
                Section("Added by you") {
                    ForEach(addedPurchases) { ManualGroceryItemLabel(item: $0) }
                }.mealWiseListRows()
            }
            Text("Receipt observations are retained with this package, quantity and store for review in later plans. Tax, deposits and fees are excluded unless entered.")
                .mealWiseListRows()
        }.mealWiseListStyle().navigationTitle("Trip summary")
    }
}

struct ShoppingHistoryView: View {
    @StateObject private var viewModel: ShoppingViewModel
    init(planID: UUID, service: any ShoppingServiceProtocol) {
        _viewModel = StateObject(wrappedValue: ShoppingViewModel(planID: planID, service: service))
    }
    var body: some View {
        List {
            if viewModel.summaries.isEmpty {
                ContentUnavailableView("No shopping trips", systemImage: "basket", description: Text("No trips have been finished for this plan."))
                    .mealWiseListRows()
            }
            ForEach(viewModel.summaries) { summary in
                NavigationLink { ShoppingSummaryView(summary: summary) } label: {
                    VStack(alignment: .leading) {
                        if let date = summary.trip.finishedAt { Text(date, format: .dateTime.month().day().hour().minute()).font(.headline) }
                        if let store = summary.trip.selectedStore { Text(LocalizedStringKey(store.label)).font(.subheadline) }
                        Text("\(summary.purchasedCount) purchased · \(summary.missingPriceCount) missing prices")
                            .font(.subheadline).foregroundStyle(DesignTokens.textSecondary)
                    }.padding(.vertical, 8)
                }.accessibilityIdentifier("shopping.history").mealWiseListRows()
            }
            if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)).mealWiseListRows() }
        }.mealWiseListStyle().navigationTitle("Shopping history").task { await viewModel.loadHistory() }
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
                Text("Compare packages of the same ingredient. Required food quantities and allergy requirements stay unchanged.").mealWiseListRows()
                if viewModel.isWorking { ProgressView("Checking package alternatives").mealWiseListRows() }
                if !viewModel.isWorking && viewModel.substitutes.isEmpty {
                    Text("No catalog-backed cheaper package fits this complete cart. Keep your current choice or review your budget.")
                        .mealWiseListRows()
                }
                ForEach(viewModel.substitutes) { option in
                    Button { selected = option } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(line.name)).font(.headline)
                            Text("Package: \(QuantityFormatting.display(amount: option.offer.packageQuantity, unit: option.offer.unit))")
                            Text("Projected cycle: \(option.projectedMinorUnits.currency)")
                        }.padding(.vertical, 8)
                    }.mealWiseListRows()
                }
                if let selected {
                    ChangePreviewCard(preview: selected.preview)
                    Section {
                        Text("The shopping projection above includes other entered receipt prices. This replacement resets only this item's check and actual price; confirm the replacement package before purchasing.")
                        Button("Use this package") { Task { if await viewModel.acceptSubstitute(selected) { dismiss() } } }
                            .buttonStyle(MealWiseButtonStyle()).disabled(viewModel.isWorking)
                    }.mealWiseListRows()
                }
                if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)).mealWiseListRows() }
            }.mealWiseListStyle()
                .navigationTitle("Cheaper packages")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Keep current package") { dismiss() }.disabled(viewModel.isWorking) } }
                .task { await viewModel.findSubstitutes(lineID: line.id) }
        }.interactiveDismissDisabled(viewModel.isWorking)
    }
}
