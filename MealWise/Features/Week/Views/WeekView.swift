import SwiftUI

struct WeekView: View {
    @Environment(AppSession.self) private var session
    @StateObject private var viewModel: WeekViewModel
    @State private var showBudget = false
    @State private var showSettings = false
    @State private var swapTarget: MealSwapTarget?
    @State private var pendingChange: PendingPlanChange?
    let isStartingNextWeek: Bool
    let onPlanNextWeek: () -> Void

    init(plan: WeeklyPlan, isStartingNextWeek: Bool, onPlanNextWeek: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: WeekViewModel(plan: plan))
        self.isStartingNextWeek = isStartingNextWeek
        self.onPlanNextWeek = onPlanNextWeek
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if viewModel.plan.closedAt != nil { Text("This week is finished. Use Plan actions to plan next week.").font(.headline) }
                    if viewModel.plan.reviewRequired == true { Text("Stock changed and the cycle needs budget review before additional purchases.").font(.headline) }
                    ingredientMapLink
                    ForEach(viewModel.plan.meals) { meal in
                        HStack(spacing: 0) {
                            NavigationLink(value: PlanRoute.meal(planID: viewModel.plan.id, mealID: meal.id)) { mealRow(meal) }
                                .buttonStyle(.plain).accessibilityIdentifier("week.meal")
                                .contextMenu { Button("Regenerate this day") { pendingChange = PendingPlanChange(change: .regenerateDay(meal.date)) }.disabled(viewModel.plan.closedAt != nil) }
                            Button { swapTarget = MealSwapTarget(id: meal.id) } label: {
                                Image("IconSwap").frame(width: 44, height: 44)
                            }.accessibilityLabel("Swap meal").accessibilityIdentifier("week.swap").disabled(viewModel.plan.closedAt != nil || viewModel.plan.cookedRecord(for: meal.id) != nil)
                        }.background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 18))
                    }
                }.padding(20)
            }
            .background(DesignTokens.surface)
            .navigationTitle("Your week")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) { budgetCard.padding(.horizontal, 20).padding(.vertical, 8).background(DesignTokens.surface) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Plan actions") {
                        Button("Plan next week", systemImage: "calendar.badge.plus", action: onPlanNextWeek)
                            .disabled(isStartingNextWeek)
                        if viewModel.plan.closedAt == nil {
                            Button("Regenerate week") { pendingChange = PendingPlanChange(change: .regenerateWeek) }
                            ForEach(viewModel.plan.profile.days.sorted(), id: \.self) { day in
                                Button { pendingChange = PendingPlanChange(change: .regenerateDay(day)) } label: {
                                    Text("Regenerate \(day.formatted(date: .abbreviated, time: .omitted))")
                                }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image("IconSettings").frame(width: 44, height: 44) }
                        .accessibilityLabel("Settings").accessibilityIdentifier("week.settings")
                }
            }
            .sheet(isPresented: $showBudget) { budgetDetail }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $swapTarget) { target in
                if let services = session.services { SwapView(plan: viewModel.plan, mealID: target.id, services: services) }
            }
            .sheet(item: $pendingChange) { request in
                if let services = session.services { ChangePreviewScreen(plan: viewModel.plan, change: request.change, services: services) }
            }
            .navigationDestination(for: PlanRoute.self) { route in
                if let services = session.services {
                    switch route {
                    case .meal(let planID, let mealID):
                        MealDetailView(planID: planID, mealID: mealID, plans: services.plans)
                    case .ingredientMap(let planID):
                        IngredientMapView(planID: planID, plans: services.plans)
                    case .ingredientDetail(let planID, let ingredientID):
                        IngredientDetailScreen(planID: planID, ingredientID: ingredientID, plans: services.plans)
                    case .remainderSuggestions(_, let ingredientID):
                        RemainderSuggestionView(plan: viewModel.plan, ingredientID: ingredientID, services: services)
                    }
                }
            }
        }
    }

    private var ingredientMapLink: some View {
        NavigationLink(value: PlanRoute.ingredientMap(planID: viewModel.plan.id)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ingredient map").font(.headline)
                    if let count = viewModel.attentionCount, count > 0 {
                        Text("\(count) leftovers to check").font(.subheadline).foregroundStyle(DesignTokens.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.forward").font(.footnote).foregroundStyle(DesignTokens.action).accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("week.map")
    }

    private var budgetCard: some View {
        Button { showBudget = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack { Text(viewModel.plan.resources == nil ? "Estimated checkout" : "Projected cycle total"); Spacer(); Text("\(viewModel.plan.remainingMinorUnits.currency) left").foregroundStyle(DesignTokens.gold) }
                    VStack(alignment: .leading) { Text(viewModel.plan.resources == nil ? "Estimated checkout" : "Projected cycle total"); Text("\(viewModel.plan.remainingMinorUnits.currency) left").foregroundStyle(DesignTokens.gold) }
                }.font(.caption)
                Text(viewModel.plan.totalMinorUnits.currency).font(.largeTitle.bold())
                Text("of \(viewModel.plan.profile.budgetMinorUnits.currency) · Sample prices").font(.subheadline)
                UsageMeter(progress: viewModel.progress, label: "Budget used", value: Text(viewModel.plan.totalMinorUnits.currency))
                    .accessibilityHidden(true)
            }.padding(18).foregroundStyle(.white)
                .background(DesignTokens.panel, in: RoundedRectangle(cornerRadius: 23))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Projected cycle total \(viewModel.plan.totalMinorUnits.currency) of \(viewModel.plan.profile.budgetMinorUnits.currency), \(viewModel.plan.remainingMinorUnits.currency) remaining. Sample prices. Budget details."))
        .accessibilityIdentifier("week.budget")
    }

    private func mealRow(_ meal: ScheduledMeal) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack {
                Text(meal.date, format: .dateTime.weekday(.abbreviated)).font(.caption)
                Text(meal.date, format: .dateTime.day()).font(.title3.bold())
            }.frame(minWidth: 40)
            RecipePhoto(recipeID: meal.recipeID, layout: .thumbnail)
            if let recipe = viewModel.recipe(for: meal) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(recipe.title)).font(.headline)
                    if viewModel.plan.cookedRecord(for: meal.id) != nil { Text("Cooked").font(.caption) }
                    Text(LocalizedStringKey(meal.slot.title)).font(.caption).foregroundStyle(DesignTokens.action)
                    Text("\(recipe.minutes) min · \(viewModel.consumptionCost(for: meal)) ingredients").font(.caption)
                    Text("\(viewModel.consumptionCost(for: meal, perServing: true)) per adult-equivalent serving").font(.caption)
                    Text("\(viewModel.sharedIngredientCount(for: meal)) shared ingredients").font(.caption).foregroundStyle(DesignTokens.action)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private var budgetDetail: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Weekly budget", value: viewModel.plan.profile.budgetMinorUnits.currency)
                    LabeledContent("Projected cycle total", value: viewModel.plan.totalMinorUnits.currency)
                    LabeledContent("Remaining", value: viewModel.plan.remainingMinorUnits.currency)
                } header: {
                    Text("Whole-package checkout estimate")
                } footer: {
                    DevelopmentNotice()
                }
                if let resources = viewModel.plan.resources {
                    Section("Purchased stock and spending") {
                        LabeledContent("Known actual spending", value: resources.knownActualMinorUnits.currency)
                        LabeledContent("Items missing actual prices", value: resources.missingPriceCount.formatted())
                        Text("Projected totals include earlier purchases and remaining whole-package checkout. Unknown receipt prices use the original estimate.")
                    }
                }
                Section("Allocated checkout averages") {
                    LabeledContent("Per planned day", value: viewModel.perDay)
                    LabeledContent("Per adult-equivalent serving", value: viewModel.checkoutPerAdultPortion)
                    Text("A child portion is half an adult portion. Checkout averages allocate packages, including leftovers; meal ingredient costs show only what is consumed.")
                        .font(.footnote)
                }
                if session.services != nil {
                    Section { NavigationLink("Adjust budget", value: BudgetRoute.adjust).disabled(viewModel.plan.closedAt != nil) }
                }
            }
            .navigationTitle("Budget details")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showBudget = false } } }
            .navigationDestination(for: BudgetRoute.self) { _ in
                if let services = session.services { BudgetAdjustmentView(plan: viewModel.plan, services: services) }
            }
        }
    }
}

#Preview { RootView().environment(AppSession()) }

private struct MealSwapTarget: Identifiable { let id: UUID }
private struct PendingPlanChange: Identifiable { let id = UUID(); let change: PlanChange }
private enum BudgetRoute: Hashable { case adjust }
