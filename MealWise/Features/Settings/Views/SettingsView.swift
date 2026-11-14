import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingReset = false
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
                    }
                    Section {
                        Button("Edit plan settings") { editing = true }.frame(minHeight: 44)
                        Text("Changing your answers creates a new plan preview. Your saved plan changes only after you accept.").font(.footnote)
                    }
                    Section {
                        Button("Start over", role: .destructive) { confirmingReset = true }.frame(minHeight: 44)
                    }
                }
                if let error { Text(LocalizedStringKey(error)) }
            }
            .navigationTitle("Plan settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Remove your current plan and setup answers?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset plan", role: .destructive) {
                    Task {
                        do { try await session.reset() }
                        catch { self.error = "Your plan could not be reset. Please retry." }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $editing) {
                if let plan = session.plan, let services = session.services {
                    NavigationStack { OnboardingView(profile: plan.profile, services: services, isEditing: true) }
                }
            }
        }
    }
}

#Preview { SettingsView().environment(AppSession()) }
