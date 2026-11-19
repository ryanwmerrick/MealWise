import SwiftUI

struct GroceryView: View {
    @StateObject private var viewModel: GroceryViewModel
    @Environment(AppSession.self) private var session
    @State private var reload = 0

    init(plan: WeeklyPlan, checklist: any ChecklistRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: GroceryViewModel(plan: plan, checklist: checklist))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MealWiseOverview(icon: "basket") {
                        Text(viewModel.plan.closedAt == nil ? LocalizedStringKey("Additional estimated checkout") : "Unpurchased forecast at close")
                            .font(.subheadline)
                        Text((try? CartCalculator.total(viewModel.plan.cart))?.currency ?? String(localized: "Unavailable"))
                            .font(.largeTitle.bold())
                        Text("Weekly budget \(viewModel.plan.profile.budgetMinorUnits.currency)")
                            .font(.subheadline)
                        Text("\(viewModel.checked.count) of \(viewModel.plan.cart.filter { $0.packageCount > 0 }.count) items checked")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(DesignTokens.gold)
                    }
                } footer: {
                    DevelopmentNotice()
                }
                if let services = session.services {
                    Section {
                        if viewModel.plan.closedAt == nil {
                            NavigationLink {
                                ShoppingView(planID: viewModel.plan.id, service: services.shopping)
                            } label: {
                                Text("Start shopping").font(.headline).foregroundStyle(DesignTokens.action)
                            }
                        } else { Text("This cycle is finished. Its unpurchased forecast is historical; plan a new week in Pantry.") }
                        NavigationLink("Shopping history") { ShoppingHistoryView(planID: viewModel.plan.id, service: services.shopping) }
                    }.mealWiseListRows()
                }
                if let resources = viewModel.plan.resources {
                    Section("Earlier purchases") {
                        LabeledContent("Known actual spending", value: resources.knownActualMinorUnits.currency)
                        LabeledContent("Items missing actual prices", value: resources.missingPriceCount.formatted())
                        Text("Purchased quantities are credited below. Only additional packages remain to buy.")
                    }.mealWiseListRows()
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Text(LocalizedStringKey(error))
                        Button("Retry") { reload += 1 }.frame(minHeight: 44)
                    }.mealWiseListRows()
                }
                ForEach(viewModel.plan.closedAt == nil ? viewModel.sections : []) { section in
                    Section(LocalizedStringKey(section.category.title)) {
                        ForEach(section.rows) { row in groceryRow(row) }
                    }.mealWiseListRows()
                }
                Section("Price information") {
                    Text(LocalizedStringKey(viewModel.plan.catalog.priceProvenance))
                    Text("Tax, deposits and fees are excluded. Checking an item is a shopping reminder, not a recorded purchase.")
                        .font(.footnote)
                }.mealWiseListRows()
            }
            .contentMargins(.top, 8, for: .scrollContent)
            .mealWiseListStyle()
            .navigationTitle("Grocery list")
            .task(id: reload) { await session.refreshPlan(); await viewModel.load() }
        }
    }

    private func groceryRow(_ row: GroceryRow) -> some View {
        Button { Task { await viewModel.toggle(row.id) } } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(viewModel.checked.contains(row.id) ? DesignTokens.brand : .clear)
                    RoundedRectangle(cornerRadius: 6).stroke(DesignTokens.action)
                    if viewModel.checked.contains(row.id) { Image("IconCheck").foregroundStyle(DesignTokens.buttonText) }
                }
                .frame(width: 24, height: 24)
                .padding(.vertical, 10)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(row.title)).font(.headline)
                    Text("\(row.packages) × \(row.packageSize)").font(.subheadline).foregroundStyle(DesignTokens.textSecondary)
                    Text("Estimated \(row.cost)").font(.subheadline.weight(.semibold))
                    Text("Price date: \(row.priceDate)").font(.caption).foregroundStyle(DesignTokens.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .foregroundStyle(DesignTokens.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSaving)
        .accessibilityAddTraits(viewModel.checked.contains(row.id) ? .isSelected : [])
        .accessibilityIdentifier("grocery.check")
    }
}

#Preview { RootView().environment(AppSession()) }
