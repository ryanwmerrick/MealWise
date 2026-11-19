import SwiftUI

struct PantryView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: PantryViewModel
    @State private var adding = false
    @State private var editing: PantryInventoryItem?
    @State private var review: ReviewSession?

    let plan: WeeklyPlan
    let services: AppServices

    private struct ReviewSession: Identifiable {
        let id = UUID()
        let items: [PantryInventoryItem]
    }

    init(plan: WeeklyPlan, services: AppServices) {
        self.plan = plan
        self.services = services
        _viewModel = StateObject(wrappedValue: PantryViewModel(planID: plan.id, repository: services.pantry))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                inventory
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .mealWiseScreenStyle()
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Review Pantry", systemImage: "checkmark.rectangle.stack") {
                        review = ReviewSession(items: viewModel.items)
                    }
                        .disabled(viewModel.items.isEmpty)
                        .accessibilityIdentifier("pantry.review")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add pantry item", systemImage: "plus") { adding = true }
                }
            }
            .task(id: plan.revision) { await viewModel.load() }
        }
        .sheet(isPresented: $adding, onDismiss: reload) {
            PantryEditorView(item: nil, services: services)
        }
        .sheet(item: $editing, onDismiss: reload) { item in
            PantryInventoryDetail(item: item, services: services)
        }
        .fullScreenCover(item: $review, onDismiss: reload) { review in
            PantryReviewView(items: review.items, pantry: services.pantry)
        }
    }

    @ViewBuilder
    private var inventory: some View {
        if let error = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Pantry unavailable", systemImage: "tray")
            } description: {
                Text(LocalizedStringKey(error))
            } actions: {
                Button("Retry", action: reload)
            }
        } else if viewModel.items.isEmpty {
            if viewModel.isLoading {
                ProgressView("Loading pantry stock")
            } else {
                ContentUnavailableView("Your pantry is empty", systemImage: "tray",
                                       description: Text("Add food you have at home or finish a shopping trip."))
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                                     count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                ForEach(viewModel.items) { item in
                    Button { editing = item } label: {
                        PantryInventoryCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pantry.item")
                }
            }
        }
    }

    private func reload() {
        Task {
            await session.refreshPlan()
            await viewModel.load()
        }
    }
}

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
                        Text("Other ingredient").tag("")
                        ForEach(viewModel.catalog.ingredients) { ingredient in Text(LocalizedStringKey(ingredient.name)).tag(ingredient.id) }
                    }.disabled(viewModel.original != nil)
                        .accessibilityIdentifier("pantry.ingredient")
                    if viewModel.ingredientID.isEmpty {
                        TextField("Ingredient name", text: $viewModel.customName)
                            .accessibilityIdentifier("pantry.customName")
                        Picker("Unit", selection: $viewModel.customUnit) {
                            Text("Count").tag(QuantityUnit.count)
                            Text("Grams").tag(QuantityUnit.milligrams)
                            Text("Milliliters").tag(QuantityUnit.milliliters)
                        }.disabled(viewModel.original != nil && viewModel.original?.unknownQuantity == nil)
                    }
                    TextField("Quantity", text: $viewModel.quantityText).keyboardType(.decimalPad).accessibilityIdentifier("pantry.quantity")
                    LabeledContent("Quantity unit", value: PantryQuantityInput.symbol(unit: viewModel.unit))
                    Toggle("I know when I got this", isOn: $viewModel.hasAcquiredDate)
                    if viewModel.hasAcquiredDate {
                        DatePicker("Date acquired", selection: $viewModel.acquiredAt, in: ...Date.now, displayedComponents: .date)
                    }
                    StorageFields(storage: $viewModel.storage, hasExpiry: $viewModel.hasExpiry, expiry: $viewModel.expiry)
                    Toggle("I have checked that this stock is available", isOn: $viewModel.available)
                    Text("Unconfirmed or expired stock stays out of planning. Check the package's actual storage instructions; unknown dates do not imply a safety guarantee.").font(.footnote)
                }.mealWiseListRows()
                Section {
                    Button("Save pantry item") { Task { if await viewModel.save() { await finish() } } }
                        .buttonStyle(MealWiseButtonStyle())
                    if viewModel.original != nil { Button("Remove this stock", role: .destructive) { confirmRemove = true }.frame(minHeight: 44) }
                }.mealWiseListRows()
                if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)).mealWiseListRows() }
            }.mealWiseListStyle()
                .disabled(viewModel.isWorking)
                .navigationTitle("Pantry item")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(viewModel.isWorking) } }
                .confirmationDialog("Remove this stock and update remaining purchases?", isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button("Remove stock", role: .destructive) { Task { if await viewModel.remove() { await finish() } } }
                }
        }.interactiveDismissDisabled(viewModel.isWorking)
    }
    private func finish() async {
        await session.refreshPlan()
        dismiss()
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
