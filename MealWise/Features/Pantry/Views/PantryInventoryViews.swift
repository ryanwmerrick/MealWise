import SwiftUI

struct PantryInventoryCard: View {
    let item: PantryInventoryItem
    var reviewHeight: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.selection.opacity(0.5))
                .frame(height: reviewHeight.map { $0 * 0.70 } ?? 78)
                .overlay {
                    Image("PantryDefaultFood")
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            Text(LocalizedStringKey(item.name)).font(reviewHeight == nil ? .headline : .title.bold())
            quantityLabel
                .font((reviewHeight == nil ? Font.subheadline : .title3).weight(.semibold))
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
        .padding(reviewHeight == nil ? 12 : 16)
        .frame(minHeight: reviewHeight, alignment: .topLeading)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0
    @State private var decisions: [Decision] = []
    @State private var isSaving = false
    @State private var showsError = false

    let items: [PantryInventoryItem]
    let pantry: any PantryRepositoryProtocol

    private enum Decision { case stillHave, out }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 12) {
                        reviewProgress
                        if decisions.count < items.count {
                            reviewCard(items[decisions.count], height: max(280, geometry.size.height - 164))
                            Text("Swipe right to keep it or left if you’re out.")
                                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
                            ViewThatFits {
                                HStack { reviewActions }
                                VStack { reviewActions }
                            }
                        } else {
                            ContentUnavailableView("All items reviewed", systemImage: "checkmark.circle",
                                                   description: Text("Save your review to update Pantry."))
                        }
                        if showsError {
                            Text("Your pantry changed. Close this review and open it again.")
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .disabled(isSaving)
                }
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

    private var reviewProgress: some View {
        HStack {
            if decisions.count < items.count {
                Text("Item \(decisions.count + 1) of \(items.count)")
                    .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
            }
            Spacer()
            if !decisions.isEmpty {
                Button("Undo last choice", systemImage: "arrow.uturn.backward") { decisions.removeLast() }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .frame(minHeight: 44)
    }

    private func reviewCard(_ item: PantryInventoryItem, height: CGFloat) -> some View {
        PantryInventoryCard(item: item, reviewHeight: height)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pantry.review.card")
            .overlay(alignment: drag > 0 ? .topLeading : .topTrailing) {
                if abs(drag) > 16 {
                    swipeFeedback(keeping: drag > 0)
                }
            }
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag) / 24))
            .offset(x: reduceMotion ? 0 : drag)
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
    }

    private func swipeFeedback(keeping: Bool) -> some View {
        Label(keeping ? LocalizedStringKey("Still have it") : "Out of it", systemImage: keeping ? "checkmark" : "xmark")
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(keeping ? DesignTokens.panel : Color(red: 0.64, green: 0.13, blue: 0.20), in: Capsule())
            .padding(26)
            .opacity(min(1, Double(abs(drag) / 54)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
