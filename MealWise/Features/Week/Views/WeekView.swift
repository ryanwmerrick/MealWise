import SwiftUI

struct WeekView: View {
    @Environment(AppSession.self) private var session
    @StateObject private var viewModel: WeekViewModel
    @State private var showBudget = false
    @State private var showSettings = false

    init(plan: WeeklyPlan) { _viewModel = StateObject(wrappedValue: WeekViewModel(plan: plan)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    DevelopmentNotice()
                    Text("Ingredients repeat on purpose.").font(.headline)
                    ForEach(viewModel.plan.meals) { meal in
                        NavigationLink(value: MealRoute.detail(planID: viewModel.plan.id, mealID: meal.id)) { mealRow(meal) }
                            .buttonStyle(.plain).accessibilityIdentifier("week.meal")
                    }
                }.padding(20)
            }
            .background(DesignTokens.surface)
            .navigationTitle("Your week")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) { budgetCard.padding(.horizontal, 20).padding(.vertical, 8).background(DesignTokens.surface) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image("IconSettings").frame(width: 44, height: 44) }
                        .accessibilityLabel("Settings").accessibilityIdentifier("week.settings")
                }
            }
            .sheet(isPresented: $showBudget) { budgetDetail }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: MealRoute.self) { route in
                if let services = session.services {
                    switch route {
                    case .detail(let planID, let mealID): MealDetailView(planID: planID, mealID: mealID, plans: services.plans)
                    }
                }
            }
        }
    }

    private var budgetCard: some View {
        Button { showBudget = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack { Text("Estimated checkout"); Spacer(); Text("\(viewModel.plan.remainingMinorUnits.currency) left").foregroundStyle(DesignTokens.gold) }
                    VStack(alignment: .leading) { Text("Estimated checkout"); Text("\(viewModel.plan.remainingMinorUnits.currency) left").foregroundStyle(DesignTokens.gold) }
                }.font(.caption)
                Text(viewModel.plan.totalMinorUnits.currency).font(.largeTitle.bold())
                Text("of \(viewModel.plan.profile.budgetMinorUnits.currency)").font(.subheadline)
                UsageMeter(progress: viewModel.progress, label: "Budget used", value: Text(viewModel.plan.totalMinorUnits.currency))
                    .accessibilityHidden(true)
            }.padding(18).foregroundStyle(.white)
                .background(DesignTokens.panel, in: RoundedRectangle(cornerRadius: 23))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Estimated checkout \(viewModel.plan.totalMinorUnits.currency) of \(viewModel.plan.profile.budgetMinorUnits.currency), \(viewModel.plan.remainingMinorUnits.currency) remaining. Budget details."))
        .accessibilityIdentifier("week.budget")
    }

    private func mealRow(_ meal: ScheduledMeal) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack {
                Text(meal.date, format: .dateTime.weekday(.abbreviated)).font(.caption)
                Text(meal.date, format: .dateTime.day()).font(.title3.bold())
            }.frame(minWidth: 40)
            Image("IconPot").padding(12).background(DesignTokens.selection, in: RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
            if let recipe = viewModel.recipe(for: meal) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(recipe.title)).font(.headline)
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
                Section("Whole-package checkout estimate") {
                    LabeledContent("Weekly budget", value: viewModel.plan.profile.budgetMinorUnits.currency)
                    LabeledContent("Estimated total", value: viewModel.plan.totalMinorUnits.currency)
                    LabeledContent("Remaining", value: viewModel.plan.remainingMinorUnits.currency)
                }
                Section("Allocated checkout averages") {
                    LabeledContent("Per planned day", value: viewModel.perDay)
                    LabeledContent("Per adult-equivalent serving", value: viewModel.checkoutPerAdultPortion)
                    Text("A child portion is half an adult portion. Checkout averages allocate packages, including leftovers; meal ingredient costs show only what is consumed.")
                        .font(.footnote)
                }
                Section { DevelopmentNotice() }
            }
            .navigationTitle("Budget details")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showBudget = false } } }
        }
    }
}

#Preview { RootView().environment(AppSession()) }
