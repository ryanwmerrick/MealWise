import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingReset = false
    @State private var confirmingErasure = false
    @State private var isErasing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let plan = session.plan {
                    Section("Current choices") {
                        LabeledContent("Weekly budget", value: plan.profile.budgetMinorUnits.currency)
                        LabeledContent("Household", value: String(localized: "Adults: \(plan.profile.adults); children: \(plan.profile.children)"))
                        LabeledContent("Days", value: plan.profile.days.count.formatted())
                        LabeledContent("Meals each day", value: plan.profile.mealSlots.count.formatted())
                        LabeledContent("Cooking time", value: String(localized: String.LocalizationValue(plan.profile.cookingTime.title)))
                        LabeledContent("Cooking experience", value: String(localized: String.LocalizationValue(plan.profile.skill.title)))
                        LabeledContent("Store", value: String(localized: "Development grocery"))
                        LabeledContent("Allergies", value: plan.profile.allergies.count.formatted())
                        LabeledContent("Preferences", value: plan.profile.preferences.count.formatted())
                        LabeledContent("Meat preference", value: (plan.profile.meatPreference ?? .noPreference).title)
                    }
                    Section {
                        Button("Edit plan settings") { editing = true }.frame(minHeight: 44).disabled(plan.closedAt != nil)
                        NavigationLink("Weekly nutrition", value: SettingsRoute.nutrition)
                        Text("Changing your answers creates a new plan preview. Your saved plan changes only after you accept.").font(.footnote)
                    }
                }
                if session.services != nil {
                    Section("Saved preferences") {
                        NavigationLink("Favorites", value: SettingsRoute.favorites)
                        NavigationLink("Excluded recipes", value: SettingsRoute.excluded)
                        NavigationLink("Cycle history", value: SettingsRoute.history)
                    }
                    Section("Local data") {
                        if session.plan != nil {
                            Button("Start over", role: .destructive) { confirmingReset = true }.frame(minHeight: 44)
                            Text("Start over removes the active plan and setup answers. Pantry, favorites and recorded history remain saved.").font(.footnote)
                        }
                        Button("Erase all local data", role: .destructive) { confirmingErasure = true }.frame(minHeight: 44)
                        Text("Clear plans, setup, pantry, preferences and history from this installation.").font(.footnote)
                    }
                }
                if let error { Text(LocalizedStringKey(error)) }
            }.disabled(isErasing)
            .navigationTitle(session.plan == nil ? "Saved data" : "Plan settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(isErasing) } }
            .confirmationDialog("Remove your current plan and setup answers?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset plan", role: .destructive) {
                    Task {
                        do { try await session.reset() }
                        catch { self.error = "Your plan could not be reset. Please retry." }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Erase all local MealWise records?", isPresented: $confirmingErasure, titleVisibility: .visible) {
                Button("Erase local data", role: .destructive) { Task { await eraseLocalData() } }
            } message: { Text("This permanently removes saved plans, pantry, favorites, ratings and history from MealWise.") }
            .fullScreenCover(isPresented: $editing) {
                if let plan = session.plan, let services = session.services {
                    NavigationStack { OnboardingView(profile: plan.profile, services: services, isEditing: true, basePlan: plan) }
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                if let services = session.services {
                    switch route {
                    case .excluded: ExcludedRecipesView(catalog: services.catalog, preferences: services.preferences)
                    case .favorites: FavoritesView(catalog: services.catalog, preferences: services.preferences)
                    case .nutrition: if let plan = session.plan { WeeklyNutritionView(plan: plan) }
                    case .history: CycleHistoryView(services: services)
                    }
                }
            }
        }
    }
    private func eraseLocalData() async {
        guard !isErasing else { return }
        isErasing = true; defer { isErasing = false }
        let hadActivePlan = session.plan != nil
        do {
            try await session.eraseLocalData()
            if !hadActivePlan { dismiss() }
        } catch { self.error = "Local records could not be erased. Please retry." }
    }
}

#Preview { SettingsView().environment(AppSession()) }
private enum SettingsRoute: Hashable { case excluded, favorites, nutrition, history }
