import SwiftUI

/// Tabs share one committed cycle snapshot.
struct MainTabView: View {
    @Environment(AppSession.self) private var session
    @State private var selectedTab = 0
    @State private var confirmingNextWeek = false
    @State private var startingNextWeek = false
    @State private var nextPlan: WeeklyPlan?
    @State private var nextWeekError = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Week", image: "IconCalendar", value: 0) {
                if let plan = session.plan {
                    WeekView(plan: plan, isStartingNextWeek: startingNextWeek, onPlanNextWeek: planNextWeek)
                        .id(plan.revision)
                }
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
        .onChange(of: session.plan?.id) { _, planID in
            if let nextPlan, nextPlan.id != planID { self.nextPlan = nil }
        }
        .navigationBarBackButtonHidden()
        .confirmationDialog("Finish this week and plan next week?", isPresented: $confirmingNextWeek, titleVisibility: .visible) {
            Button("Finish this week") { Task { await finishWeek() } }
        } message: {
            Text("Your remaining food stays in Pantry. This week’s plan and receipts move to history.")
        }
        .alert("Could not finish this week", isPresented: $nextWeekError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Refresh your plan and try again.")
        }
        .fullScreenCover(item: $nextPlan) { closedPlan in
            if let services = session.services { NextWeekView(plan: closedPlan, services: services) }
        }
    }

    private func planNextWeek() {
        guard let plan = session.plan, !startingNextWeek else { return }
        if plan.closedAt == nil { confirmingNextWeek = true }
        else { nextPlan = plan }
    }

    private func finishWeek() async {
        guard let plan = session.plan, let services = session.services, !startingNextWeek else { return }
        startingNextWeek = true
        defer { startingNextWeek = false }
        do {
            try await services.pantry.finishWeek(planID: plan.id, revision: plan.revision)
            guard let closed = try await services.plans.loadActivePlan(),
                  closed.id == plan.id, closed.closedAt != nil else { throw PantryError.staleStock }
            session.accept(closed)
            nextPlan = closed
        } catch {
            nextWeekError = true
            await session.refreshPlan()
        }
    }
}

#Preview { MainTabView().environment(AppSession()) }
