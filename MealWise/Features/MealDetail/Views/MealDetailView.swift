import SwiftUI

struct MealDetailView: View {
    @StateObject private var viewModel: MealDetailViewModel
    @State private var reload = 0

    init(planID: UUID, mealID: UUID, plans: any PlanRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: MealDetailViewModel(planID: planID, mealID: mealID, plans: plans))
    }

    var body: some View {
        Group {
            if let detail = viewModel.detail, let plan = viewModel.plan {
                recipeContent(detail, plan: plan)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Meal unavailable", systemImage: "exclamationmark.triangle")
                } description: { Text(LocalizedStringKey(error)) } actions: {
                    Button("Retry") { reload += 1 }.frame(minHeight: 44)
                }
            } else { ProgressView("Opening recipe") }
        }
        .background(DesignTokens.surface)
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reload) { await viewModel.load() }
    }

    private func recipeContent(_ detail: MealDetail, plan: WeeklyPlan) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    RecipePhoto(recipeID: detail.recipeID, layout: .hero)
                    Text(LocalizedStringKey(detail.title)).font(.title.bold()).accessibilityAddTraits(.isHeader)
                    Text("\(detail.minutes) minutes · \(String(localized: String.LocalizationValue(detail.skill.title)))").font(.subheadline)
                    Text("Adults: \(plan.profile.adults) · Children: \(plan.profile.children)")
                    Text("Adult-equivalent portions: \((Decimal(detail.adultHalfPortions) / 2).formatted(.number))")
                    LabeledContent("Consumed ingredients", value: detail.ingredientCost.formatted(.currency(code: "USD")))
                    LabeledContent("Per adult-equivalent serving", value: (detail.ingredientCost * 2 / Decimal(detail.adultHalfPortions)).formatted(.currency(code: "USD")))
                }.padding(.vertical, 8)
            }
            Section("Ingredients for this meal") {
                ForEach(detail.ingredients) { ingredient in
                    LabeledContent {
                        Text(QuantityFormatting.display(amount: ingredient.amount, unit: ingredient.unit))
                    } label: { Text(LocalizedStringKey(ingredient.name)) }
                }
                Text("These are the amounts to use for this meal. Your grocery list rounds the combined week up to whole packages.")
                    .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
            }
            Section("Recipe steps") {
                ForEach(detail.steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        Text(step.number.formatted()).font(.headline).foregroundStyle(DesignTokens.action)
                        Text(LocalizedStringKey(step.instruction)).fixedSize(horizontal: false, vertical: true)
                    }.padding(.vertical, 8)
                }
            }
            Section("Simple balance indicators") {
                nutritionRow("Vegetables", included: detail.nutrition.vegetable)
                nutritionRow("Protein", included: detail.nutrition.protein)
                nutritionRow("Whole grains", included: detail.nutrition.wholeGrain)
            }
            if !detail.linkedMeals.isEmpty {
                Section("Other meals using these ingredients") {
                    ForEach(detail.linkedMeals) { meal in
                        NavigationLink(value: PlanRoute.meal(planID: plan.id, mealID: meal.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey(plan.catalog.recipes.first { $0.id == meal.recipeID }?.title ?? "Meal"))
                                Text(meal.date, format: .dateTime.weekday().month().day()).font(.caption)
                            }
                        }
                        .accessibilityIdentifier("recipe.related")
                    }
                }
            }
            if !viewModel.reservations.isEmpty {
                Section {
                    DisclosureGroup("Save for later meals") {
                        ReservationNotes(notes: viewModel.reservations)
                    }
                }
            }
        }.listStyle(.insetGrouped)
    }

    private func nutritionRow(_ title: LocalizedStringKey, included: Bool) -> some View {
        LabeledContent { Text(included ? LocalizedStringKey("Included") : LocalizedStringKey("Not indicated")) } label: { Text(title) }
    }
}

#Preview { RootView().environment(AppSession()) }
