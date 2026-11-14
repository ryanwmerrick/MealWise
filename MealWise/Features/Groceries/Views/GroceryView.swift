import SwiftUI

struct GroceryView: View {
    @StateObject private var viewModel: GroceryViewModel
    @State private var reload = 0

    init(plan: WeeklyPlan, checklist: any ChecklistRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: GroceryViewModel(plan: plan, checklist: checklist))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Estimated checkout", value: viewModel.plan.totalMinorUnits.currency).font(.headline)
                    LabeledContent("Budget", value: viewModel.plan.profile.budgetMinorUnits.currency)
                    Text("\(viewModel.checked.count) of \(viewModel.plan.cart.count) items checked")
                    DevelopmentNotice()
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Text(LocalizedStringKey(error))
                        Button("Retry") { reload += 1 }.frame(minHeight: 44)
                    }
                }
                ForEach(viewModel.sections) { section in
                    Section(LocalizedStringKey(section.category.title)) {
                        ForEach(section.rows) { row in groceryRow(row) }
                    }
                }
                Section("Price information") {
                    Text(LocalizedStringKey(viewModel.plan.catalog.priceProvenance))
                    Text("Tax, deposits and fees are excluded. Checking an item is a shopping reminder, not a recorded purchase.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Grocery list")
            .task(id: reload) { await viewModel.load() }
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
                    Text("\(row.packages) × \(row.packageSize)").font(.caption)
                    Text("Estimated \(row.cost)").font(.subheadline)
                    Text("Price date: \(row.priceDate)").font(.caption2)
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
