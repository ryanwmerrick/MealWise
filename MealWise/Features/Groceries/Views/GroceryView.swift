import SwiftUI

struct GroceryView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: GroceryViewModel
    @State private var path: [Route] = []
    @State private var reload = 0
    @State private var showingAddItem = false

    let plan: WeeklyPlan
    let shopping: any ShoppingServiceProtocol

    init(plan: WeeklyPlan, shopping: any ShoppingServiceProtocol) {
        self.plan = plan
        self.shopping = shopping
        _viewModel = StateObject(wrappedValue: GroceryViewModel(planID: plan.id, shopping: shopping))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    MealWiseOverview(icon: "basket") {
                        Text("Estimated Cost").font(.subheadline)
                        Text(viewModel.estimatedCost(for: plan).currency)
                            .font(.largeTitle.bold().monospacedDigit())
                            .accessibilityIdentifier("grocery.estimatedCost")
                        Text("Weekly budget \(plan.profile.budgetMinorUnits.currency)").font(.subheadline)
                    }
                }
                if plan.closedAt != nil {
                    Text("This week is finished. Open Week to plan next week.").mealWiseListRows()
                } else {
                    listHeading
                    groceryList
                }
            }
            .listSectionSpacing(4)
            .environment(\.defaultMinListHeaderHeight, 20)
            .environment(\.defaultMinListRowHeight, 40)
            .contentMargins(.top, 4, for: .scrollContent)
            .mealWiseListStyle()
            .navigationTitle("Groceries")
            .toolbar {
                if plan.closedAt == nil && (plan.cart.contains(where: { $0.packageCount > 0 }) || !viewModel.manualItems(for: plan).isEmpty) {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { path.append(.shopping) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .accessibilityHidden(true)
                                Text(shoppingActionTitle)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        .accessibilityLabel(Text(shoppingActionTitle))
                        .accessibilityIdentifier("grocery.start")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Shopping history", systemImage: "clock.arrow.circlepath") { path.append(.history) }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("grocery.history")
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddGroceryItemView(save: viewModel.addManualItem)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .shopping:
                    ShoppingView(planID: plan.id, service: shopping) { receipt in
                        path = [.receipt(receipt)]
                    }
                case .history:
                    ShoppingHistoryView(planID: plan.id, service: shopping)
                case .receipt(let receipt):
                    ShoppingSummaryView(summary: receipt)
                }
            }
            .task(id: Refresh(revision: plan.revision, isVisible: path.isEmpty && scenePhase == .active, attempt: reload)) {
                guard path.isEmpty, scenePhase == .active else { return }
                await session.refreshPlan()
                guard plan.closedAt == nil, !Task.isCancelled else { return }
                await viewModel.load()
            }
        }
    }

    private var shoppingActionTitle: LocalizedStringKey {
        viewModel.hasActiveTrip(for: plan) ? "Resume Shopping" : "Start Shopping"
    }

    private var listHeading: some View {
        HStack {
            Text("Your List").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { showingAddItem = true } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.action)
                    .frame(width: 44, height: 44)
                    .background(DesignTokens.card, in: Circle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Add grocery item")
            .accessibilityIdentifier("grocery.add")
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var groceryList: some View {
        if let error = viewModel.errorMessage {
            Section {
                Text(LocalizedStringKey(error))
                Button("Retry") { reload += 1 }.frame(minHeight: 44)
            }.mealWiseListRows()
        }

        let manualItems = viewModel.manualItems(for: plan)
        if !manualItems.isEmpty {
            Section("Added by you") {
                ForEach(manualItems) { item in
                    ManualGroceryItemLabel(item: item)
                        .listRowInsets(.vertical, 3)
                        .swipeActions {
                            Button("Remove", role: .destructive) {
                                Task { await viewModel.removeManualItem(item.id) }
                            }
                        }
                }
            }.mealWiseListRows()
        }
        let sections = viewModel.sections(for: plan)
        if sections.isEmpty && manualItems.isEmpty {
            Text("No groceries left to buy for this week.").mealWiseListRows()
        }
        ForEach(sections) { section in
            Section(LocalizedStringKey(section.category.title)) {
                ForEach(section.rows) { row in
                    GroceryItemLabel(name: row.title, packages: row.packages, packageSize: row.packageSize, costMinorUnits: row.costMinorUnits)
                        .listRowInsets(.vertical, 3)
                        .accessibilityElement(children: .combine)
                }
            }.mealWiseListRows()
        }
    }

    private enum Route: Hashable {
        case shopping, history, receipt(ShoppingSummary)
    }

    private struct Refresh: Hashable {
        let revision: UUID
        let isVisible: Bool
        let attempt: Int
    }
}

private struct AddGroceryItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = ""
    @State private var isSaving = false
    @State private var showsError = false

    let save: (String, String) async throws -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ingredient", text: $name)
                    TextField("Quantity (optional)", text: $quantity)
                }.mealWiseListRows()
                if showsError {
                    Text("The item could not be added. Please try again.").mealWiseListRows()
                }
            }
            .mealWiseListStyle()
            .navigationTitle("Add Grocery Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await addItem() } }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func addItem() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await save(name, quantity)
            dismiss()
        } catch {
            showsError = true
        }
    }
}

#Preview { RootView().environment(AppSession()) }
