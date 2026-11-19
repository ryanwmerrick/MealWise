import SwiftUI

struct WeeklyNutritionView: View {
    let plan: WeeklyPlan
    var body: some View {
        List {
            if let summary = try? WeeklyNutritionSummary(plan: plan) {
                Section("Meal balance") {
                    Text("Planned meals: \(summary.meals)")
                    Text("Meals with vegetables: \(summary.vegetable) of \(summary.meals)").accessibilityIdentifier("nutrition.vegetable")
                    Text("Meals with protein: \(summary.protein) of \(summary.meals)")
                    Text("Meals with whole grains: \(summary.wholeGrain) of \(summary.meals)")
                }.mealWiseListRows()
                Section {
                    Text("Each scheduled meal slot counts once, including repeat recipes. Cooked meals retain their original recipe indicators.")
                    Text("These counts show which meals include each food group. They use sample recipe data.")
                }.mealWiseListRows()
            } else {
                ContentUnavailableView("Summary unavailable", systemImage: "leaf", description: Text("A recipe could not be read. Your plan remains saved."))
                    .mealWiseListRows()
            }
        }
        .mealWiseListStyle()
        .navigationTitle("Weekly nutrition")
    }
}

#Preview { RootView().environment(AppSession()) }
