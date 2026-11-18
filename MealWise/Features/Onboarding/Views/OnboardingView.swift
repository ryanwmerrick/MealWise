import SwiftUI

struct OnboardingView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OnboardingViewModel
    @State private var buildRequest: UUID?
    @FocusState private var budgetFocused: Bool
    @AccessibilityFocusState private var errorFocused: Bool
    @ScaledMetric(relativeTo: .body) private var presetWidth = 72
    let isEditing: Bool

    init(profile: PlanningProfile, services: AppServices, isEditing: Bool = false, basePlan: WeeklyPlan? = nil, nextCycle: WeeklyPlan? = nil, planningCatalog: RecipeCatalog? = nil) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(profile: profile, services: services, now: nextCycle == nil ? .now : (profile.days.min() ?? .now), basePlan: basePlan, nextCycle: nextCycle, planningCatalog: planningCatalog))
        self.isEditing = isEditing
    }

    var body: some View {
        Group {
            if viewModel.isBuilding { building }
            else if let preview = viewModel.preview { comparison(preview) }
            else { setup }
        }
        .background(DesignTokens.surface)
        .navigationBarBackButtonHidden()
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = viewModel.errorMessage {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your plan needs attention").font(.headline)
                        Text(LocalizedStringKey(error)).font(.callout)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color("NoteText"))
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("NoteFill"))
                .overlay(alignment: .bottom) { Rectangle().fill(Color("NoteText")).frame(height: 2) }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("setup.error.banner")
                .accessibilityFocused($errorFocused)
                .onAppear { errorFocused = true }
            }
        }
        .task(id: viewModel.profile) {
            if let saved = await viewModel.saveDraft() { session.rememberDraft(saved) }
        }
        .task(id: buildRequest) {
            guard buildRequest != nil else { return }
            await viewModel.build()
            if !isEditing, viewModel.preview != nil { await accept() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { budgetFocused = false }
            }
        }
    }

    private var setup: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    if viewModel.step == 0 {
                        Task {
                            if let saved = await viewModel.saveDraft() { session.rememberDraft(saved) }
                            dismiss()
                        }
                    } else { viewModel.back() }
                } label: { Image("IconBack").frame(width: 44, height: 44) }
                    .accessibilityLabel("Go back")
                ProgressView(value: Double(viewModel.step + 1), total: 8).tint(DesignTokens.action)
                Text("\(viewModel.step + 1) of 8").font(.caption)
            }
            .padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(stepTitle).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    controls
                }.padding(22).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            Button {
                budgetFocused = false
                if viewModel.step == 7 { buildRequest = UUID() } else { viewModel.advance() }
            } label: {
                if viewModel.step == 7 { Text("Build my plan") } else { Text("Continue") }
            }
            .buttonStyle(MealWiseButtonStyle())
            .disabled(!viewModel.canContinue)
            .accessibilityIdentifier(viewModel.step == 7 ? "setup.build" : "setup.continue")
            .padding(22)
        }
    }

    private var stepTitle: LocalizedStringKey {
        switch viewModel.step {
        case 0: "What can you spend this week?"
        case 1: "Who are you cooking for?"
        case 2: "Which days should we plan?"
        case 3: "How much time do you have?"
        case 4: "How comfortable are you cooking?"
        case 5: "Choose your grocery store"
        case 6: "Any needs or preferences?"
        default: "Does everything look right?"
        }
    }

    @ViewBuilder private var controls: some View {
        switch viewModel.step {
        case 0: budgetControl
        case 1: householdControl
        case 2: scheduleControl
        case 3:
            ForEach(CookingTime.allCases, id: \.self) { time in
                ChoiceRow(title: LocalizedStringKey(time.title), isSelected: viewModel.profile.cookingTime == time) {
                    viewModel.profile.cookingTime = time
                }
            }
        case 4:
            ForEach(CookingSkill.allCases, id: \.self) { skill in
                ChoiceRow(title: LocalizedStringKey(skill.title), isSelected: viewModel.profile.skill == skill) {
                    viewModel.profile.skill = skill
                }
            }
        case 5:
            ChoiceRow(title: "Development grocery", isSelected: true) { viewModel.profile.storeID = "development-grocery" }
            Text("Synthetic package prices for development. No retailer location or availability is implied.")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
        case 6: foodControl
        default: summary
        }
    }

    private var budgetControl: some View {
        VStack(spacing: 24) {
            TextField("Weekly budget in dollars", text: $viewModel.budgetText)
                .keyboardType(.decimalPad).focused($budgetFocused)
                .font(.largeTitle.bold()).multilineTextAlignment(.center)
                .accessibilityIdentifier("setup.budget")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: presetWidth))]) {
                ForEach([40, 55, 70, 90], id: \.self) { amount in
                    Button { viewModel.budgetText = String(amount) } label: {
                        Text(Int64(amount * 100).currency).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("budget.preset.\(amount)")
                }
            }
            Text("The estimate includes whole packages and required staples. Tax, deposits and fees are excluded.")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
            if viewModel.profile.budgetMinorUnits <= 0 {
                Text("Enter a positive dollar amount with at most two decimal places.")
                    .font(.callout)
            }
        }
    }

    private var householdControl: some View {
        VStack(spacing: 24) {
            Stepper(value: $viewModel.profile.adults, in: 1...12) {
                Text("Adults, age 13+: \(viewModel.profile.adults)")
            }
            Stepper(value: $viewModel.profile.children, in: 0...11) {
                Text("Children, age 2–12: \(viewModel.profile.children)")
            }
            Text("Children use half an adult portion for planning. Meals for children under two are outside this planner. Maximum household: 12 people.")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private var scheduleControl: some View {
        VStack(alignment: .leading, spacing: 20) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))]) {
                ForEach(viewModel.selectableDates, id: \.self) { date in
                    Button { viewModel.toggleDay(date) } label: {
                        VStack {
                            Text(date, format: .dateTime.weekday(.abbreviated))
                            Text(date, format: .dateTime.month(.abbreviated).day())
                        }.padding(10).frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.profile.days.contains(date) ? DesignTokens.action : DesignTokens.textSecondary)
                    .accessibilityAddTraits(viewModel.profile.days.contains(date) ? .isSelected : [])
                }
            }
            Text("Meals to include").font(.headline)
            ForEach(MealSlot.allCases, id: \.self) { slot in
                ChoiceRow(title: LocalizedStringKey(slot.title), isSelected: viewModel.profile.mealSlots.contains(slot)) {
                    viewModel.toggleSlot(slot)
                }
            }
            Text("Choose at least one day and one meal.").font(.footnote)
        }
    }

    private var foodControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allergies").font(.headline)
            Text("Diet and allergy filters use simulated ingredient declarations in this development catalog. Plans are not verified for allergy-safe use; check actual product labels and cross-contact information before cooking.")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
            ForEach(Allergen.allCases, id: \.self) { allergy in
                ChoiceRow(title: LocalizedStringKey(allergy.title), isSelected: viewModel.profile.allergies.contains(allergy)) {
                    viewModel.toggleAllergy(allergy)
                }
            }
            Text("Preferences").font(.headline)
            ForEach(DietPreference.allCases, id: \.self) { preference in
                ChoiceRow(title: LocalizedStringKey(preference.title), isSelected: viewModel.profile.preferences.contains(preference)) {
                    viewModel.togglePreference(preference)
                }
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 12) {
            summaryRow("Weekly budget", value: viewModel.profile.budgetMinorUnits.currency, step: 0, id: "budget")
            summaryRow("Household", value: String(localized: "Adults: \(viewModel.profile.adults); children: \(viewModel.profile.children)"), step: 1, id: "household")
            summaryRow("Schedule", value: String(localized: "\(viewModel.profile.days.count) days, \(viewModel.profile.mealSlots.count) meals per day"), step: 2, id: "schedule")
            summaryRow("Cooking time", value: String(localized: String.LocalizationValue(viewModel.profile.cookingTime.title)), step: 3, id: "time")
            summaryRow("Cooking experience", value: String(localized: String.LocalizationValue(viewModel.profile.skill.title)), step: 4, id: "skill")
            summaryRow("Store", value: String(localized: "Development grocery"), step: 5, id: "store")
            summaryRow("Food needs", value: String(localized: "\(viewModel.profile.allergies.count) allergies, \(viewModel.profile.preferences.count) preferences"), step: 6, id: "food")
            DevelopmentNotice()
        }
    }

    private func summaryRow(_ title: LocalizedStringKey, value: String, step: Int, id: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(DesignTokens.textSecondary)
                Text(value).font(.headline)
            }
            Spacer()
            Button("Edit") { viewModel.edit(step) }.frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(Text("Edit \(Text(title))"))
                .accessibilityIdentifier("summary.edit.\(id)")
        }.padding().background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private var building: some View {
        VStack(spacing: 24) {
            Image("IconPot").scaleEffect(2).padding(30).accessibilityHidden(true)
            Text("Building your week").font(.largeTitle.bold())
            ProgressView().tint(.white)
            Text("Checking shared ingredients and whole-package costs.")
            Text("Your budget: \(viewModel.profile.budgetMinorUnits.currency)")
        }.multilineTextAlignment(.center).padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white).background(DesignTokens.panel)
    }

    private func comparison(_ preview: WeeklyPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Review your new plan").font(.largeTitle.bold())
                if let current = session.plan, viewModel.nextCycle == nil {
                    LabeledContent("Current estimate", value: current.totalMinorUnits.currency)
                }
                LabeledContent("New estimate", value: preview.totalMinorUnits.currency)
                LabeledContent("New budget", value: preview.profile.budgetMinorUnits.currency)
                LabeledContent("Remaining", value: preview.remainingMinorUnits.currency)
                if viewModel.nextCycle != nil {
                    Text("Accepting starts a separate cycle. Completed history is preserved, and confirmed stock is reserved once.")
                    if let savings = try? PantrySavings.estimate(plan: preview) { LabeledContent("Estimated package savings from pantry", value: savings.currency) }
                    DisclosureGroup("Review stock used") {
                        ForEach(preview.resources?.pantryCredits ?? []) { credit in
                            LabeledContent { Text(QuantityFormatting.display(amount: credit.remainingQuantity, unit: credit.unit)) }
                                label: { Text(LocalizedStringKey(preview.catalog.ingredients.first { $0.id == credit.ingredientID }?.name ?? "Ingredient")) }
                                .accessibilityIdentifier("next.stock.credit")
                        }
                    }
                } else { Text("Accepting replaces your current planned week. Your new estimate stays within the selected budget.") }
                DisclosureGroup("Review dates and meals") {
                    ForEach(preview.meals) { meal in
                        VStack(alignment: .leading) {
                            Text(meal.date, format: .dateTime.weekday().month().day())
                            Text(LocalizedStringKey(preview.catalog.recipes.first { $0.id == meal.recipeID }?.title ?? "Meal"))
                        }.padding(.vertical, 6)
                    }
                }
                Button("Accept new plan") { Task { await accept() } }.buttonStyle(MealWiseButtonStyle())
                Button("Edit answers") { viewModel.edit(7) }.buttonStyle(MealWiseButtonStyle(kind: .secondary))
                if isEditing { Button("Keep current plan") { dismiss() }.frame(minHeight: 44) }
            }.padding(22)
        }
    }

    private func accept() async {
        if let plan = await viewModel.acceptPreview() { session.accept(plan) }
    }
}

#Preview { RootView().environment(AppSession()) }
