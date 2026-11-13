import SwiftUI

/// Phase 1 contains navigation foundations; later phases supply committed plan content.
struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Week", image: "IconCalendar") {
                emptyState("No weekly plan yet", detail: "Your meals will appear here after setup.", icon: "IconCalendar")
            }
            Tab("Groceries", image: "IconBasket") {
                emptyState("No groceries yet", detail: "Your grocery list will come from your weekly plan.", icon: "IconBasket")
            }
            Tab("Today", image: "IconPot") {
                emptyState("No meal scheduled", detail: "Your planned meals will guide you through the day.", icon: "IconPot")
            }
            Tab("Pantry", image: "IconPantry") {
                emptyState("Your pantry is empty", detail: "Confirmed ingredients left over from a week will appear here.", icon: "IconPantry")
            }
        }
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

#Preview { MainTabView() }
