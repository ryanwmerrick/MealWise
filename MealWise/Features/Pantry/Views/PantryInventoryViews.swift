import SwiftUI

struct PantryInventoryCard: View {
    let item: PantryInventoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.selection.opacity(0.5))
                .frame(height: 78)
                .accessibilityHidden(true)

            Text(LocalizedStringKey(item.name)).font(.headline)
            quantityLabel
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignTokens.action)
            if let date = item.acquiredAt {
                ageLabel(date)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .accessibilityLabel(Text("Acquired \(date, format: .dateTime.month().day().year())"))
            } else {
                Text("Date unknown").font(.caption).foregroundStyle(DesignTokens.textSecondary)
            }
            if !item.availabilityConfirmed {
                Text("Unconfirmed").font(.caption2).foregroundStyle(DesignTokens.textSecondary)
            }
            if let shelfDate = item.shelfDate {
                Text("Use-by \(shelfDate, format: .dateTime.month().day())")
                    .font(.caption2).foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .foregroundStyle(DesignTokens.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(DesignTokens.card, in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
    }

    private var quantityLabel: Text {
        if let unknown = item.savedItem?.unknownQuantity {
            return unknown.isEmpty ? Text("Amount unknown") : Text(unknown)
        }
        return Text("\(QuantityFormatting.display(amount: item.quantity, unit: item.unit)) left")
    }

    private func ageLabel(_ date: Date) -> Text {
        let calendar = Calendar.autoupdatingCurrent
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: .now)).day ?? 0
        if days <= 0 { return Text("Got it today") }
        if days == 1 { return Text("Got it yesterday") }
        return Text("\(days) days ago")
    }
}

struct PantryInventoryDetail: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var confirmingRemoval = false
    @State private var editingDetails = false
    @State private var isSaving = false
    @State private var showsError = false

    let item: PantryInventoryItem
    let services: AppServices

    private var amountUsed: Int64? {
        guard let parsed = try? PantryQuantityInput.parse(amount, unit: item.unit),
              parsed > 0, parsed <= item.quantity else { return nil }
        return parsed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if item.savedItem?.unknownQuantity != nil {
                        Text("Set the amount in Edit details before recording use.")
                    } else {
                        LabeledContent("Amount left", value: QuantityFormatting.display(amount: item.quantity, unit: item.unit))
                        TextField("Amount used", text: $amount).keyboardType(.decimalPad)
                        LabeledContent("Quantity unit", value: PantryQuantityInput.symbol(unit: item.unit))
                        Button("Use some") {
                            if let amountUsed { Task { await save(quantity: item.quantity - amountUsed) } }
                        }
                        .disabled(amountUsed == nil || isSaving)
                    }
                }.mealWiseListRows()
                Section {
                    if item.savedItem != nil {
                        Button("Edit details") { editingDetails = true }.disabled(isSaving)
                    }
                    Button("Remove item", role: .destructive) { confirmingRemoval = true }
                        .disabled(isSaving)
                }.mealWiseListRows()
                if showsError {
                    Text("This item could not be updated. Reopen it and try again.").mealWiseListRows()
                }
            }
            .mealWiseListStyle()
            .navigationTitle(Text(LocalizedStringKey(item.name)))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.disabled(isSaving)
                }
            }
            .confirmationDialog("Remove this item from Pantry?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                Button("Remove item", role: .destructive) { Task { await save(quantity: 0, remove: true) } }
            }
            .sheet(isPresented: $editingDetails, onDismiss: { dismiss() }) {
                if let saved = item.savedItem { PantryEditorView(item: saved, services: services) }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save(quantity: Int64, remove: Bool = false) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await services.pantry.applyInventory([PantryInventoryEdit(item: item, quantity: quantity, remove: remove)])
            dismiss()
        } catch {
            showsError = true
        }
    }
}

struct PantryReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @GestureState private var drag: CGFloat = 0
    @State private var decisions: [Decision] = []
    @State private var isSaving = false
    @State private var showsError = false

    let items: [PantryInventoryItem]
    let pantry: any PantryRepositoryProtocol

    private enum Decision { case stillHave, out }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if decisions.count < items.count {
                        reviewCard(items[decisions.count])
                        ViewThatFits {
                            HStack { reviewActions }
                            VStack { reviewActions }
                        }
                    } else {
                        ContentUnavailableView("All items reviewed", systemImage: "checkmark.circle",
                                               description: Text("Save your review to update Pantry."))
                    }
                    if !decisions.isEmpty {
                        Button("Undo last choice", systemImage: "arrow.uturn.backward") { decisions.removeLast() }
                            .frame(minHeight: 44)
                    }
                    if showsError {
                        Text("Your pantry changed. Close this review and open it again.")
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
                .padding(20)
                .disabled(isSaving)
            }
            .mealWiseScreenStyle()
            .navigationTitle("Review Pantry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Review") { Task { await save() } }
                        .disabled(decisions.isEmpty || isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func reviewCard(_ item: PantryInventoryItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Item \(decisions.count + 1) of \(items.count)")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
            PantryInventoryCard(item: item)
                .offset(x: drag)
                .rotationEffect(.degrees(Double(drag) / 18))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .updating($drag) { value, state, _ in
                            if abs(value.translation.width) > abs(value.translation.height) { state = value.translation.width }
                        }
                        .onEnded { value in
                            let horizontal = value.translation.width
                            guard abs(horizontal) > 65, abs(horizontal) > abs(value.translation.height) else { return }
                            choose(horizontal > 0 ? .stillHave : .out)
                        }
                )
            Text("Swipe right to keep it or left if you’re out.")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
        }
    }

    @ViewBuilder
    private var reviewActions: some View {
        Button("Out of it", systemImage: "xmark") { choose(.out) }
            .buttonStyle(MealWiseButtonStyle(kind: .secondary))
        Button("Still have it", systemImage: "checkmark") { choose(.stillHave) }
            .buttonStyle(MealWiseButtonStyle())
    }

    private func choose(_ decision: Decision) {
        guard decisions.count < items.count, !isSaving else { return }
        decisions.append(decision)
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let edits = zip(items, decisions).map { item, decision in
                PantryInventoryEdit(item: item, quantity: decision == .out ? 0 : item.quantity,
                                    confirmAvailability: decision == .stillHave, remove: decision == .out)
            }
            try await pantry.applyInventory(edits)
            dismiss()
        } catch {
            showsError = true
        }
    }
}
