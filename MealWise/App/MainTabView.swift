import SwiftUI

/// Phase 1 contains navigation foundations; later phases supply committed plan content.
struct MainTabView: View {
    @Environment(AppSession.self) private var session
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Week", image: "IconCalendar", value: 0) {
                if let plan = session.plan { WeekView(plan: plan).id(plan.revision) }
            }
            Tab("Groceries", image: "IconBasket", value: 1) {
                if let plan = session.plan, let services = session.services {
                    GroceryView(plan: plan, checklist: services.checklist).id(plan.revision)
                }
            }
            Tab("Today", image: "IconPot", value: 2) {
                emptyState("No meal scheduled", detail: "Your planned meals will guide you through the day.", icon: "IconPot")
            }
            Tab("Pantry", image: "IconPantry", value: 3) {
                emptyState("Your pantry is empty", detail: "Confirmed ingredients left over from a week will appear here.", icon: "IconPantry")
            }
        }
        .onChange(of: selectedTab) { Task { await session.refreshPlan() } }
        .navigationBarBackButtonHidden()
    }

    private func emptyState(_ title: LocalizedStringKey, detail: LocalizedStringKey, icon: String) -> some View {
        ContentUnavailableView {
            Label { Text(title) } icon: { Image(icon) }
        } description: {
            Text(detail)
        }
        .foregroundStyle(DesignTokens.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.surface)
    }
}

#Preview { MainTabView().environment(AppSession()) }
