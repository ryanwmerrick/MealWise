import SwiftUI

struct TodayView: View {
    @StateObject private var viewModel: TodayViewModel
    @State private var cooking: TodayMealTarget?
    @State private var skipped: TodayMealTarget?
    let services: AppServices
    init(plan: WeeklyPlan, services: AppServices) {
        self.services = services; _viewModel = StateObject(wrappedValue: TodayViewModel(plan: plan))
    }
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                List {
                    Section {
                        Text(context.date, format: .dateTime.weekday().month().day()).font(.headline)
                        DevelopmentNotice()
                    }
                    if viewModel.plan.closedAt != nil {
                        Text("This cycle is finished. Open Pantry to plan your next week.").font(.headline)
                    }
                    if viewModel.plan.closedAt == nil && viewModel.meals(on: context.date).isEmpty {
                        ContentUnavailableView("No meal scheduled today", systemImage: "calendar", description: Text("Your saved plan has no meals on this local date. Open Week to review its dates."))
                    }
                    ForEach(viewModel.plan.closedAt == nil ? viewModel.meals(on: context.date) : []) { meal in
                        Section(LocalizedStringKey(meal.slot.title)) {
                            Button { cooking = TodayMealTarget(id: meal.id) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(LocalizedStringKey(viewModel.recipe(for: meal)?.title ?? "Meal")).font(.headline)
                                    if let recipe = viewModel.recipe(for: meal) {
                                        Text("\(recipe.minutes) min · \(String(localized: String.LocalizationValue(recipe.skill.title)))").font(.subheadline)
                                    }
                                    if let cost = viewModel.estimatedCost(for: meal) { Text("Estimated ingredients: \(cost)").font(.caption) }
                                    if viewModel.isCooked(meal) { Text("Cooked") }
                                    else { Text("Open cooking steps") }
                                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }.accessibilityIdentifier("today.meal")
                            if viewModel.isCooked(meal) { MealRatingView(mealID: meal.id, preferences: services.preferences) }
                            if !viewModel.isCooked(meal) {
                                Button("I didn’t cook this") { skipped = TodayMealTarget(id: meal.id) }.frame(minHeight: 44).accessibilityIdentifier("today.skip")
                            }
                        }
                    }
                }
            }.navigationTitle("Today")
        }
        .fullScreenCover(item: $cooking) { target in CookingView(planID: viewModel.plan.id, mealID: target.id, services: services) }
        .sheet(item: $skipped) { target in
            if let meal = viewModel.plan.meals.first(where: { $0.id == target.id }) {
                SkipMealView(meal: meal, plan: viewModel.plan, targets: viewModel.moveTargets(for: meal), services: services)
            }
        }
    }
}

private struct TodayMealTarget: Identifiable { let id: UUID }

private struct SkipMealView: View {
    @Environment(\.dismiss) private var dismiss
    let meal: ScheduledMeal
    let plan: WeeklyPlan
    let targets: [ScheduledMeal]
    let services: AppServices
    @State private var selected: TodayMealTarget?
    var body: some View {
        NavigationStack {
            List {
                Section("Reschedule without consuming ingredients") {
                    Text("No ingredients are consumed by opening or cancelling this preview. Choose another uncooked meal in the same slot to exchange cooking dates.")
                    Text("Moving a meal can change which ingredients must be saved for later. Freshness is uncertain; check package storage and use-by instructions. No shelf-life guarantee is assumed.")
                }
                if targets.isEmpty { Text("There is no other uncooked meal in this slot to exchange dates with. Your current plan is unchanged.") }
                ForEach(targets) { target in
                    Button { selected = TodayMealTarget(id: target.id) } label: {
                        VStack(alignment: .leading) {
                            Text(target.date, format: .dateTime.weekday().month().day())
                            Text(LocalizedStringKey(plan.catalog.recipes.first { $0.id == target.recipeID }?.title ?? "Meal"))
                        }.padding(.vertical, 8)
                    }.accessibilityIdentifier("skip.date")
                }
            }.navigationTitle("Review cooking dates")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Keep cooking dates") { dismiss() } } }
                .sheet(item: $selected) { target in
                    if let other = targets.first(where: { $0.id == target.id }) {
                        ChangePreviewScreen(plan: plan, change: .move(mealID: meal.id, date: other.date), services: services)
                    }
                }
        }
    }
}

#Preview { RootView().environment(AppSession()) }
