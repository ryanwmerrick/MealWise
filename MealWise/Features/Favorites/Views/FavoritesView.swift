import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel
    @State private var selected: Recipe?
    init(catalog: RecipeCatalog, preferences: any MealPreferenceRepositoryProtocol, profile: PlanningProfile? = nil) {
        _viewModel = StateObject(wrappedValue: FavoritesViewModel(catalog: catalog, profile: profile, repository: preferences))
    }
    var body: some View {
        List {
            Section("Your saved recipes") {
                if viewModel.isLoading { ProgressView("Loading favorites") }
                if !viewModel.isLoading && viewModel.favorites.isEmpty { Text("No favorites yet. Rate a cooked meal in Today to save what you liked.") }
                ForEach(viewModel.favorites) { recipe in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey(recipe.title)).font(.headline)
                        if viewModel.profile != nil { Button("Pin into next plan") { selected = recipe }.frame(minHeight: 44) }
                        Button("Remove favorite") { Task { await viewModel.removeFavorite(recipe) } }.frame(minHeight: 44)
                    }.accessibilityIdentifier("favorite.recipe")
                }
            }
            Section("Pending next-plan pins") {
                Text("Each pin selects a recipe for one date and meal slot. Review these pins if you change your next week’s schedule.").font(.footnote)
                if viewModel.pins.isEmpty { Text("No pending pins") }
                ForEach(viewModel.pins) { pin in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey(viewModel.catalog.recipes.first { $0.id == pin.recipeID }?.title ?? "Unavailable recipe"))
                        Text("\(pin.date.formatted(date: .abbreviated, time: .omitted)) · \(String(localized: String.LocalizationValue(pin.slot.title)))")
                        Button("Remove pin") { Task { await viewModel.removePin(pin) } }.frame(minHeight: 44)
                    }
                }
            }
            if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)); Button("Reload favorites") { Task { await viewModel.load() } } }
        }.buttonStyle(.borderless).navigationTitle("Favorites").task { await viewModel.load() }
            .sheet(item: $selected) { recipe in
                if let profile = viewModel.profile { FavoritePinView(recipe: recipe, profile: profile, viewModel: viewModel) }
            }
    }
}

private struct FavoritePinView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let profile: PlanningProfile
    @ObservedObject var viewModel: FavoritesViewModel
    @State private var date: Date
    @State private var slot: MealSlot
    init(recipe: Recipe, profile: PlanningProfile, viewModel: FavoritesViewModel) {
        self.recipe = recipe; self.profile = profile; self.viewModel = viewModel
        _date = State(initialValue: profile.days.sorted().first ?? .now)
        _slot = State(initialValue: profile.mealSlots.sorted { $0.rawValue < $1.rawValue }.first ?? .dinner)
    }
    var body: some View {
        NavigationStack {
            Form {
                Text(LocalizedStringKey(recipe.title)).font(.headline)
                Picker("Cooking date", selection: $date) { ForEach(profile.days.sorted(), id: \.self) { Text($0, style: .date).tag($0) } }
                Picker("Meal slot", selection: $slot) { ForEach(MealSlot.allCases.filter { profile.mealSlots.contains($0) }, id: \.self) { Text(LocalizedStringKey($0.title)).tag($0) } }
                Text("The full plan must still fit your budget and food requirements. This saves a request; it does not change your current plan.")
                Button("Save next-plan pin") { Task { if await viewModel.pin(recipeID: recipe.id, date: date, slot: slot) { dismiss() } } }.frame(minHeight: 44)
                if let error = viewModel.errorMessage { Text(LocalizedStringKey(error)) }
            }.navigationTitle("Pin favorite")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

#Preview { RootView().environment(AppSession()) }
