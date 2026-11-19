import SwiftUI

/// Tabs share one committed cycle snapshot.
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
                    GroceryView(plan: plan, shopping: services.shopping).id(plan.id)
                }
            }
            Tab("Today", image: "IconPot", value: 2) {
                if let plan = session.plan, let services = session.services { TodayView(plan: plan, services: services).id(plan.revision) }
            }
            Tab("Pantry", image: "IconPantry", value: 3) {
                if let plan = session.plan, let services = session.services { PantryView(plan: plan, services: services).id(plan.id) }
            }
        }
        .onChange(of: selectedTab) { Task { await session.refreshPlan() } }
        .navigationBarBackButtonHidden()
    }


}

#Preview { MainTabView().environment(AppSession()) }
