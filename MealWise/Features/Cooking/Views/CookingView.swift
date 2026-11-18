import SwiftUI

struct CookingView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: CookingViewModel
    @State private var confirm = false
    @State private var minutes = 5
    init(planID: UUID, mealID: UUID, services: AppServices) {
        _viewModel = StateObject(wrappedValue: CookingViewModel(planID: planID, mealID: mealID, services: services))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let detail = viewModel.detail {
                        cookingCard {
                            Text(LocalizedStringKey(detail.title)).font(.title2.bold())
                            Text("\(detail.minutes) min · \((Decimal(detail.adultHalfPortions) / 2).formatted(.number)) adult-equivalent portions")
                            if viewModel.isCooked { Text("This meal is recorded as cooked. Its recipe and portions are preserved.") }
                            DevelopmentNotice()
                        }
                        cookingCard("Use for this meal") {
                            ForEach(detail.ingredients) { item in
                                if dynamicTypeSize.isAccessibilitySize {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(LocalizedStringKey(item.name)).font(.headline).accessibilityIdentifier("cooking.ingredient.name")
                                        Text(QuantityFormatting.display(amount: item.amount, unit: item.unit)).accessibilityIdentifier("cooking.ingredient.quantity")
                                    }.foregroundStyle(DesignTokens.textPrimary).accessibilityElement(children: .combine)
                                } else {
                                    LabeledContent { Text(QuantityFormatting.display(amount: item.amount, unit: item.unit)).foregroundStyle(DesignTokens.textPrimary).accessibilityIdentifier("cooking.ingredient.quantity") }
                                        label: { Text(LocalizedStringKey(item.name)).foregroundStyle(DesignTokens.textPrimary).accessibilityIdentifier("cooking.ingredient.name") }
                                }
                            }
                        }
                        if !viewModel.notes.isEmpty {
                            cookingCard("Save for later meals") { ReservationNotes(notes: viewModel.notes) }
                        }
                        cookingCard("Cooking steps") {
                            Text("Your step checks save as you go. Closing cooking does not mark this meal as cooked.").font(.footnote)
                            ForEach(detail.steps) { step in
                                Button { Task { await viewModel.toggleStep(step.number) } } label: {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Image(systemName: viewModel.progress?.completedSteps.contains(step.number) == true ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                                            Text("Step \(step.number)").font(.headline)
                                        }
                                        Text(LocalizedStringKey(step.instruction)).fixedSize(horizontal: false, vertical: true)
                                    }.padding(.vertical, 10).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }.buttonStyle(.plain).disabled(viewModel.isCooked)
                                    .accessibilityAddTraits(viewModel.progress?.completedSteps.contains(step.number) == true ? .isSelected : [])
                                    .accessibilityIdentifier("cooking.step")
                            }
                        }
                        if !viewModel.isCooked {
                            cookingCard("Optional reminder timer") {
                                if let timer = viewModel.progress?.timer {
                                    TimelineView(.periodic(from: .now, by: 1)) { context in
                                        let remaining = timer.remaining(at: context.date)
                                        if remaining == 0 { Text("Timer finished. Check your cooking.").font(.headline) }
                                        else { Text("\(remaining / 60) min \(remaining % 60) sec remaining").font(.title3.monospacedDigit()) }
                                    }
                                    Text(timer.deadline, format: .dateTime.hour().minute().second())
                                    Button("Clear timer") { Task { await viewModel.cancelTimer() } }.frame(minHeight: 44)
                                } else {
                                    Stepper("Reminder: \(minutes) minutes", value: $minutes, in: 1...180)
                                    Button("Start reminder timer") { Task { await viewModel.startTimer(minutes: minutes) } }.frame(minHeight: 44)
                                }
                                Text("This user-set reminder saves its deadline and resumes after backgrounding. Follow the recipe and package guidance; a timer does not establish food safety.").font(.footnote)
                            }
                            cookingCard {
                                if !viewModel.hasStock {
                                    Text("Record purchased packages in Groceries before confirming completion. Planned packages are not confirmed stock.")
                                }
                                Button("Mark as cooked") { confirm = true }.frame(minHeight: 44).disabled(!viewModel.hasStock)
                            }
                        }
                    }
                    if viewModel.isWorking { ProgressView("Saving cooking progress") }
                    if let error = viewModel.errorMessage {
                        Text(LocalizedStringKey(error))
                        Button("Reload cooking") { Task { await viewModel.load() } }.frame(minHeight: 44)
                    }
                }.padding(20)
            }
            .background(DesignTokens.surface)
            .disabled(viewModel.isWorking)
            .navigationTitle("Cooking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close cooking", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly).disabled(viewModel.isWorking) } }
            .task { await viewModel.load() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await viewModel.load() } } }
            .confirmationDialog("Record this meal as cooked?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Confirm cooked") {
                    Task { if await viewModel.complete() { await session.refreshPlan() } }
                }
            } message: { Text("The meal's quantities will be recorded as consumed once. Purchased and cooked history will be preserved.") }
        }.interactiveDismissDisabled(viewModel.isWorking)
    }

    private func cookingCard<Content: View>(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title { Text(title).font(.headline).accessibilityAddTraits(.isHeader) }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview { RootView().environment(AppSession()) }
