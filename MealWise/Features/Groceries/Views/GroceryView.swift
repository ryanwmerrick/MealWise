import SwiftUI

struct GroceryView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: GroceryViewModel
    @State private var path: [Route] = []
    @State private var reload = 0

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
                } footer: {
                    Text("Uses actual prices when entered and sample prices for the rest.")
                        .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
                }
                if plan.closedAt != nil {
                    Text("This cycle is finished. Open Pantry to plan your next week.").mealWiseListRows()
                } else {
                    groceryList
                }
            }
            .listSectionSpacing(12)
            .contentMargins(.top, 8, for: .scrollContent)
            .mealWiseListStyle()
            .navigationTitle("Groceries")
            .toolbar {
                if plan.closedAt == nil && plan.cart.contains(where: { $0.packageCount > 0 }) {
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

    @ViewBuilder
    private var groceryList: some View {
        if let error = viewModel.errorMessage {
            Section {
                Text(LocalizedStringKey(error))
                Button("Retry") { reload += 1 }.frame(minHeight: 44)
            }.mealWiseListRows()
        }

        let sections = viewModel.sections(for: plan)
        if sections.isEmpty {
            Text("No groceries left to buy for this week.").mealWiseListRows()
        }
        ForEach(sections) { section in
            Section(LocalizedStringKey(section.category.title)) {
                ForEach(section.rows) { row in
                    GroceryItemLabel(name: row.title, packages: row.packages, packageSize: row.packageSize, costMinorUnits: row.costMinorUnits)
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

#Preview { RootView().environment(AppSession()) }
