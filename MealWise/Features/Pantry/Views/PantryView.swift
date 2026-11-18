import SwiftUI

struct PantryView: View {
    @Environment(AppSession.self) private var session
    @StateObject private var viewModel: PantryViewModel
    @State private var adding = false
    @State private var editing: PantryItem?
    @State private var wrapping = false
    @State private var nextWeek = false
    let plan: WeeklyPlan
    let services: AppServices
    init(plan: WeeklyPlan, services: AppServices) {
        self.plan = plan; self.services = services
        _viewModel = StateObject(wrappedValue: PantryViewModel(repository: services.pantry))
    }
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                List {
                    Section("Weekly cycle") {
                        if plan.closedAt != nil {
                            Text("This cycle is finished. Its purchases and cooked meals remain in history.")
                            Button("Plan next week") { nextWeek = true }.frame(minHeight: 44)
                        } else {
                            Button("Wrap up this cycle") { wrapping = true }.frame(minHeight: 44)
                            Text("Confirm actual remaining stock before carrying it over. Forecast leftovers are not pantry inventory.").font(.footnote)
                        }
                        NavigationLink("Cycle history", value: PantryRoute.history)
                    }
                    if let savings = try? PantrySavings.estimate(plan: plan), savings > 0 {
                        Section("Estimated package savings") {
                            Text(savings.currency).font(.title2.bold())
                            Text("Same meals, with and without confirmed pantry stock. Whole-package purchases determine savings; this is not a receipt refund.").font(.footnote)
                        }
                    }
                    if viewModel.isLoading { ProgressView("Loading pantry stock") }
                    if !viewModel.isLoading && viewModel.items.isEmpty { Section { Text("No confirmed stock is in your pantry. Add an item or confirm leftovers at wrap-up.") } }
                    ForEach(viewModel.items) { item in
                        Button { editing = item } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStringKey(services.catalog.ingredients.first { $0.id == item.ingredientID }?.name ?? "Unavailable ingredient")).font(.headline)
                                Text("Recorded: \(QuantityFormatting.display(amount: item.quantity, unit: item.unit))")
                                Text("Unallocated: \(QuantityFormatting.display(amount: item.availableQuantity, unit: item.unit))")
                                if item.reservations.values.contains(where: { $0 > 0 }) { Text("Some stock is reserved for a plan.").font(.caption) }
                                Text(LocalizedStringKey(item.storage?.title ?? "Unknown storage"))
                                if let expiry = item.expiry { Text("Label/use-by: \(expiry.formatted(date: .abbreviated, time: .omitted))") }
                                else { Text("Label date unknown; availability needs your confirmation.") }
                                if !item.availabilityConfirmed || item.expiry.map({ $0 < context.date }) == true { Text("Excluded from new planning").font(.caption) }
                            }.foregroundStyle(DesignTokens.textPrimary).padding(.vertical, 8)
                        }.accessibilityIdentifier("pantry.item")
                    }
                    if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)); Button("Reload pantry") { Task { await viewModel.load() } } }
                    Section { DevelopmentNotice() }
                }
            }.navigationTitle("Pantry")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Add pantry item", systemImage: "plus") { adding = true } } }
                .navigationDestination(for: PantryRoute.self) { _ in CycleHistoryView(services: services) }
                .task { await viewModel.load() }
        }
        .sheet(isPresented: $adding, onDismiss: { Task { await viewModel.load() } }) { PantryEditorView(item: nil, services: services) }
        .sheet(item: $editing, onDismiss: { Task { await viewModel.load() } }) { item in PantryEditorView(item: item, services: services) }
        .fullScreenCover(isPresented: $wrapping) { WrapUpView(planID: plan.id, services: services) }
        .fullScreenCover(isPresented: $nextWeek) { NextWeekView(plan: plan, services: services) }
    }
}

private enum PantryRoute: Hashable { case history }

struct PantryEditorView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PantryEditorViewModel
    @State private var confirmRemove = false
    init(item: PantryItem?, services: AppServices) {
        _viewModel = StateObject(wrappedValue: PantryEditorViewModel(item: item, catalog: services.catalog, repository: services.pantry))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Count what you have") {
                    Picker("Ingredient", selection: $viewModel.ingredientID) {
                        ForEach(viewModel.catalog.ingredients) { ingredient in Text(LocalizedStringKey(ingredient.name)).tag(ingredient.id) }
                    }.disabled(viewModel.original != nil)
                    TextField("Quantity", text: $viewModel.quantityText).keyboardType(.decimalPad).accessibilityIdentifier("pantry.quantity")
                    Text("Quantity unit: \(PantryQuantityInput.symbol(unit: viewModel.unit))")
                    StorageFields(storage: $viewModel.storage, hasExpiry: $viewModel.hasExpiry, expiry: $viewModel.expiry)
                    Toggle("I have checked that this stock is available", isOn: $viewModel.available)
                    Text("Unconfirmed or expired stock stays out of planning. Check the package's actual storage instructions; unknown dates do not imply a safety guarantee.").font(.footnote)
                }
                Section {
                    Button("Save pantry item") { Task { if await viewModel.save() { await finish() } } }.frame(minHeight: 44)
                    if viewModel.original != nil { Button("Remove this stock", role: .destructive) { confirmRemove = true }.frame(minHeight: 44) }
                    Text("Changes recalculate remaining meal requirements. Cooked history stays unchanged; a shortage can require more purchases and budget review.").font(.footnote)
                }
                if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
            }.disabled(viewModel.isWorking)
                .navigationTitle("Pantry item")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(viewModel.isWorking) } }
                .confirmationDialog("Remove this stock and update remaining purchases?", isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button("Remove stock", role: .destructive) { Task { if await viewModel.remove() { await finish() } } }
                }
        }.interactiveDismissDisabled(viewModel.isWorking)
    }
    private func finish() async {
        let previous = session.plan?.revision
        await session.refreshPlan()
        if session.plan?.revision == previous { dismiss() }
    }
}

struct StorageFields: View {
    @Binding var storage: StorageKind?
    @Binding var hasExpiry: Bool
    @Binding var expiry: Date
    var body: some View {
        Picker("Storage", selection: $storage) {
            Text("Unknown storage").tag(StorageKind?.none)
            ForEach(StorageKind.allCases, id: \.self) { value in Text(LocalizedStringKey(value.title)).tag(Optional(value)) }
        }
        Toggle("I have a label/use-by date", isOn: $hasExpiry)
        if hasExpiry { DatePicker("Label/use-by date", selection: $expiry, displayedComponents: .date) }
    }
}

#Preview { RootView().environment(AppSession()) }
