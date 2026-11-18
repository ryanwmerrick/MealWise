import SwiftUI

struct NextWeekView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: NextWeekViewModel
    @State private var path: [NextWeekSetupDestination] = []
    @State private var showingFavorites = false
    @State private var preparationError: String?
    init(plan: WeeklyPlan, services: AppServices) { _viewModel = StateObject(wrappedValue: NextWeekViewModel(plan: plan, services: services)) }
    var body: some View {
        NavigationStack(path: $path) {
            List {
                if viewModel.isLoading { ProgressView("Loading next-week choices") }
                Section("A separate weekly cycle") {
                    Text("Your completed cycle stays in history. Review the next dates and choices in setup before accepting a new plan.")
                    if let first = viewModel.profile.days.min(), let last = viewModel.profile.days.max() {
                        Text("\(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                Section { Button("Favorites and next-plan pins") { showingFavorites = true }.frame(minHeight: 44) }
                Section("Confirmed pantry stock") {
                    if !viewModel.isLoading && viewModel.stock.isEmpty { Text("No pantry stock is available. The new plan will price all needed packages.") }
                    ForEach(viewModel.stock) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(viewModel.services.catalog.ingredients.first { $0.id == item.ingredientID }?.name ?? "Ingredient"))
                            Text("Unallocated: \(QuantityFormatting.display(amount: item.availableQuantity, unit: item.unit))")
                            if !item.availabilityConfirmed || item.expiry.map({ $0 < .now }) == true { Text("Excluded from new planning").font(.caption) }
                        }
                    }
                    Text("Only confirmed stock without a known expired label date is considered. Unknown dates remain uncertain. Quantities are reserved atomically after you accept; a preview reserves nothing.").font(.footnote)
                }
                if !viewModel.observations.isEmpty {
                    Section("Receipt estimates for review") {
                        Text("Optionally approve estimates based on recorded receipts. Package averages round up to a cent. Actual receipts and the original catalog validity window stay unchanged.").font(.footnote)
                        ForEach(viewModel.observations) { observation in
                            Toggle(isOn: Binding(get: { viewModel.selectedObservations.contains(observation.id) }, set: { value in
                                if value { viewModel.selectedObservations.insert(observation.id) } else { viewModel.selectedObservations.remove(observation.id) }
                            })) {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let offer = viewModel.services.catalog.offers.first(where: { $0.id == observation.offerID }) {
                                        Text(LocalizedStringKey(viewModel.services.catalog.ingredients.first { $0.id == offer.ingredientID }?.name ?? "Ingredient"))
                                    }
                                    Text("Recorded: \(observation.actualMinorUnits.currency) for \(observation.packageCount) packages")
                                    Text("Future estimate: \(observation.estimatedUnitMinorUnits.currency) per package")
                                    Text(observation.recordedAt, format: .dateTime.month().day().year()).font(.caption)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button("Review next-week setup") {
                        do { let catalog = try viewModel.reviewedCatalog(); preparationError = nil; path.append(NextWeekSetupDestination(id: UUID(), catalog: catalog)) }
                        catch { preparationError = "These price observations could not be used. Clear the selections or update the development catalog." }
                    }.frame(minHeight: 44).disabled(viewModel.isLoading || viewModel.errorMessage != nil)
                }
                if let message = preparationError { Text(LocalizedStringKey(message)) }
                if let message = viewModel.errorMessage { Text(LocalizedStringKey(message)); Button("Reload next week") { Task { await viewModel.load() } } }
            }.navigationTitle("Plan next week")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Keep current cycle") { dismiss() } } }
                .task { await viewModel.load() }
                .sheet(isPresented: $showingFavorites) {
                    NavigationStack {
                        FavoritesView(catalog: viewModel.services.catalog, preferences: viewModel.services.preferences, profile: viewModel.profile)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingFavorites = false } } }
                    }
                }
                .navigationDestination(for: NextWeekSetupDestination.self) { destination in
                    OnboardingView(profile: viewModel.profile, services: viewModel.services, isEditing: true,
                                   nextCycle: viewModel.closedPlan, planningCatalog: destination.catalog)
                }
        }
    }
}
private struct NextWeekSetupDestination: Hashable {
    let id: UUID
    let catalog: RecipeCatalog
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
