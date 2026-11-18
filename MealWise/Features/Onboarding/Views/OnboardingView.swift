import SwiftUI

struct OnboardingView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OnboardingViewModel
    @State private var buildRequest: UUID?
    @State private var showingFavorites = false
    @FocusState private var budgetFocused: Bool
    @AccessibilityFocusState private var errorFocused: Bool
    @State private var budgetEstimate: OnboardingViewModel.BudgetEstimate?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var budgetAmountSize = 68
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
        .sheet(isPresented: $showingFavorites) {
            NavigationStack {
                FavoritesView(catalog: viewModel.planningCatalog, preferences: viewModel.services.preferences, profile: viewModel.profile)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingFavorites = false } } }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !viewModel.isBuilding, let error = viewModel.errorMessage {
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
            await viewModel.build(minimumDisplay: .milliseconds(1800))
            if !Task.isCancelled, !isEditing, viewModel.preview != nil { await accept() }
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
                    if viewModel.step == .goals && !viewModel.returnToSummary {
                        Task {
                            if let saved = await viewModel.saveDraft() { session.rememberDraft(saved) }
                            dismiss()
                        }
                    } else { viewModel.back() }
                } label: {
                    Image(systemName: "chevron.left").font(.headline)
                        .frame(width: 44, height: 44)
                        .background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 14))
                }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go back")
                ProgressView(value: Double(viewModel.step.rawValue + 1), total: Double(OnboardingViewModel.Step.allCases.count)).tint(DesignTokens.action)
            }
            .padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(stepTitle).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    controls
                }.padding(22).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .id(viewModel.step)
            Button {
                budgetFocused = false
                if viewModel.step == .summary { buildRequest = UUID() } else { viewModel.advance() }
            } label: {
                if viewModel.step == .summary { Text("Build my plan") } else { Text("Continue") }
            }
            .buttonStyle(MealWiseButtonStyle())
            .disabled(!viewModel.canContinue)
            .accessibilityIdentifier(viewModel.step == .summary ? "setup.build" : "setup.continue")
            .padding(22)
        }
    }

    private var stepTitle: LocalizedStringKey {
        switch viewModel.step {
        case .goals: "What is your goal?"
        case .household: "Who are you cooking for?"
        case .schedule: "Which days are you cooking?"
        case .kitchen: "What’s in your kitchen?"
        case .time: "How much time do you have to prepare each meal?"
        case .skill: "How comfortable are you cooking?"
        case .style: "How do you like to cook?"
        case .stores: "Where do you shop?"
        case .diet: "What are your dietary preferences?"
        case .allergies: "Do you have any food allergies?"
        case .budget: "What can you spend weekly?"
        case .summary: "Does everything look right?"
        }
    }

    private var preferences: OnboardingPreferences {
        viewModel.profile.onboarding ?? OnboardingPreferences()
    }

    @ViewBuilder private var controls: some View {
        switch viewModel.step {
        case .goals:
            Text("Pick as many as you like.").foregroundStyle(DesignTokens.textSecondary)
            ForEach(PlanningGoal.allCases, id: \.self) { goal in
                SetupChoice(LocalizedStringKey(goal.label), icon: goal.symbol, selected: preferences.goals.contains(goal)) {
                    viewModel.togglePreference(goal, in: \.goals)
                }
            }
        case .household: householdControl
        case .schedule: scheduleControl
        case .kitchen:
            Text("Choose the appliances you can cook with.")
                .foregroundStyle(DesignTokens.textSecondary)
            choiceGrid {
                ForEach(KitchenEquipment.appliances, id: \.self) { tool in
                    SetupChoice(LocalizedStringKey(tool.rawValue.capitalized), selected: preferences.equipment.contains(tool)) {
                        viewModel.togglePreference(tool, in: \.equipment)
                    }
                }
            }
        case .time:
            ForEach(CookingTime.allCases, id: \.self) { time in
                SetupChoice(LocalizedStringKey(time.title), icon: "clock", selected: viewModel.profile.cookingTime == time) {
                    viewModel.profile.cookingTime = time
                }
            }
        case .skill:
            ForEach(CookingSkill.allCases, id: \.self) { skill in
                SetupChoice(LocalizedStringKey(skill.title), selected: viewModel.profile.skill == skill) {
                    viewModel.profile.skill = skill
                }
            }
        case .style:
            Text("Choose the kinds of meals you’d like to see more often.").foregroundStyle(DesignTokens.textSecondary)
            ForEach(CookingStyle.allCases, id: \.self) { style in
                SetupChoice(LocalizedStringKey(style.label), selected: preferences.styles.contains(style)) {
                    viewModel.togglePreference(style, in: \.styles)
                }
            }
        case .stores: storeControl
        case .diet: dietControl
        case .allergies: allergyControl
        case .budget: budgetControl
        case .summary: summary
        }
    }

    private var budgetControl: some View {
        let snapshot = viewModel.profile
        let meals = snapshot.days.count * snapshot.mealSlots.count
        let halfPortions = meals * snapshot.adultHalfPortions
        return VStack(spacing: 22) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$").font(.title2.weight(.semibold))
                    .foregroundStyle(DesignTokens.action)
                    .accessibilityHidden(true)
                Text(viewModel.budgetText.isEmpty ? "0" : viewModel.budgetText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .padding(.horizontal, 4)
                    .hidden()
                    .overlay {
                        TextField("0", text: $viewModel.budgetText)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .focused($budgetFocused)
                            .accessibilityLabel("Weekly budget in dollars")
                            .accessibilityIdentifier("setup.budget")
                    }
            }
            .font(.system(size: budgetAmountSize, weight: .bold, design: .rounded).monospacedDigit())
            .padding(.top, 26)
            SetupBudgetPicker(budget: $viewModel.budgetText, minorUnits: snapshot.budgetMinorUnits)
            VStack(spacing: 7) {
                if halfPortions > 0 {
                    let perPortion = (Decimal(snapshot.budgetMinorUnits) * 2 / 100 / Decimal(halfPortions))
                        .formatted(.currency(code: "USD"))
                    Text("\(perPortion) per adult portion · \(meals) meals")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("setup.budget.perServing")
                }
                if !viewModel.canContinue {
                    Text("Enter a budget above $0.")
                } else {
                    switch budgetEstimate {
                    case .fits(let cost, let remaining):
                        Text("Est. groceries \(cost.currency) · \(remaining.currency) left")
                        Text("Sample prices").font(.caption)
                    case .message(let message):
                        Text(LocalizedStringKey(message))
                    case nil:
                        ProgressView("Checking your budget…").controlSize(.small)
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(DesignTokens.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .task(id: snapshot) {
            budgetEstimate = nil
            guard viewModel.canContinue else { return }
            do {
                try await Task.sleep(for: .milliseconds(450))
                let estimate = try await viewModel.budgetEstimate(for: snapshot)
                try Task.checkCancellation()
                budgetEstimate = estimate
            } catch {
                if !Task.isCancelled { budgetEstimate = .message("The estimate is unavailable. You can still build your plan.") }
            }
        }
    }

    private var householdControl: some View {
        VStack(spacing: 12) {
            Stepper(value: $viewModel.profile.adults, in: 1...(12 - viewModel.profile.children)) {
                householdLabel("Adults", detail: "Age 13 and up", count: viewModel.profile.adults, symbol: "person.fill")
            }
            .padding().background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 18))
            Stepper(value: $viewModel.profile.children, in: 0...(12 - viewModel.profile.adults)) {
                householdLabel("Children", detail: "Ages 2–12", count: viewModel.profile.children, symbol: "figure.child")
            }
            .padding().background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 18))
            Text("Children use half an adult portion. Plan for up to 12 people.")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private func householdLabel(_ title: LocalizedStringKey, detail: LocalizedStringKey, count: Int, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(DesignTokens.action).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(DesignTokens.textSecondary)
            }
            Spacer(minLength: 4)
            Text(count, format: .number).font(.title2.bold()).monospacedDigit()
        }
    }

    private var scheduleControl: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Choose the days you usually cook.").foregroundStyle(DesignTokens.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: typeSize.isAccessibilitySize ? 4 : 7), spacing: 8) {
                ForEach(viewModel.upcomingDates, id: \.self) { date in
                    let selected = viewModel.isDaySelected(date)
                    Button { viewModel.toggleDay(date) } label: {
                        VStack(spacing: 8) {
                            Text(date, format: .dateTime.weekday(.narrow)).font(.subheadline.bold())
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .foregroundStyle(selected ? DesignTokens.action : DesignTokens.textSecondary)
                        .background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 16))
                        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? DesignTokens.action : DesignTokens.textSecondary.opacity(0.2)) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide)))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Text("Meals to include").font(.headline)
            ForEach(MealSlot.allCases, id: \.self) { slot in
                SetupChoice(LocalizedStringKey(slot.title), icon: mealIcon(slot), selected: viewModel.profile.mealSlots.contains(slot)) {
                    viewModel.toggleSlot(slot)
                }
            }
            Text("Choose at least one day and one meal.").font(.footnote).foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private func mealIcon(_ slot: MealSlot) -> String {
        switch slot {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        }
    }

    private func choiceGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 8, content: content)
    }

    private var storeControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick all the stores you shop at. We’ll save your choices. Grocery estimates currently use sample prices.")
                .foregroundStyle(DesignTokens.textSecondary)
            choiceGrid {
                ForEach(GroceryPreference.allCases, id: \.self) { store in
                    let selected = preferences.stores.contains(store)
                    Button {
                        viewModel.togglePreference(store, in: \.stores)
                    } label: {
                        VStack(spacing: 10) {
                            Group {
                                if let logo = store.logoAsset {
                                    Image(logo).resizable().scaledToFit().padding(7)
                                } else {
                                    Image(systemName: "cart").foregroundStyle(.black)
                                }
                            }
                            .frame(width: 92, height: 42)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityHidden(true)
                            HStack(spacing: 6) {
                                Text(store.label).font(.subheadline.weight(.semibold))
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected ? DesignTokens.action : DesignTokens.textSecondary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(10).frame(maxWidth: .infinity, minHeight: 74)
                        .background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 16))
                        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? DesignTokens.action : DesignTokens.textSecondary.opacity(0.2)) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var dietControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Used in your plan").font(.headline)
            choiceGrid {
                ForEach(DietPreference.allCases, id: \.self) { preference in
                    SetupChoice(LocalizedStringKey(preference.title), selected: viewModel.profile.preferences.contains(preference)) {
                        viewModel.togglePreference(preference)
                    }
                }
            }
            Text("Saved to your profile").font(.headline)
                .padding(.top, 8)
            Text("The current catalog doesn’t use these choices to filter meals.")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
            choiceGrid {
                SetupChoice("Keto", selected: preferences.keto) { viewModel.toggleKeto() }
                ForEach(AdditionalDietPreference.allCases, id: \.self) { diet in
                    SetupChoice(LocalizedStringKey(diet.rawValue.capitalized), selected: preferences.additionalDiets?.contains(diet) == true) {
                        viewModel.toggleAdditionalDiet(diet)
                    }
                }
            }
        }
    }

    private var allergyControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose any groups you need to avoid. You can also select specific foods below.")
                .foregroundStyle(DesignTokens.textSecondary)
            choiceGrid {
                ForEach(Allergen.allCases, id: \.self) { allergy in
                    SetupChoice(LocalizedStringKey(allergy.title), selected: viewModel.wholeAllergyGroups.contains(allergy)) {
                        viewModel.toggleAllergy(allergy)
                    }
                }
            }
            Text("Specific foods").font(.headline)
            Text("A specific choice excludes its entire group. For example, selecting shrimp excludes all shellfish.")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
            detailedAllergyGroup("Individual tree nuts", group: .treeNut)
            detailedAllergyGroup("Individual shellfish", group: .shellfish)
            detailedAllergyGroup("Individual fish", group: .fish)
            Text("The catalog can’t screen for allergies outside this list. These filters use sample ingredient data. Check product labels and cross-contact information before cooking.")
                .font(.footnote).foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private func detailedAllergyGroup(_ title: LocalizedStringKey, group: Allergen) -> some View {
        let details = DetailedFoodAllergy.allCases.filter { $0.group == group }
        let selected = preferences.detailedAllergies ?? []
        let count = details.filter(selected.contains).count
        return DisclosureGroup {
            choiceGrid {
                ForEach(details, id: \.self) { food in
                    SetupChoice(LocalizedStringKey(food.rawValue.capitalized), selected: selected.contains(food)) {
                        viewModel.toggleDetailedAllergy(food)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                if count > 0 { Text("\(count) selected").font(.footnote).foregroundStyle(DesignTokens.textSecondary) }
            }
            .frame(minHeight: 32)
        }
        .padding(10)
        .background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var summary: some View {
        VStack(spacing: 12) {
            summaryRow("Weekly budget", value: viewModel.profile.budgetMinorUnits.currency, step: .budget, id: "budget")
            summaryRow("Household", value: String(localized: "Adults: \(viewModel.profile.adults); children: \(viewModel.profile.children)"), step: .household, id: "household")
            summaryRow("Schedule", value: String(localized: "\(viewModel.profile.days.count) days, \(viewModel.profile.mealSlots.count) meals per day"), step: .schedule, id: "schedule")
            summaryRow("Cooking time", value: String(localized: String.LocalizationValue(viewModel.profile.cookingTime.title)), step: .time, id: "time")
            summaryRow("Cooking experience", value: String(localized: String.LocalizationValue(viewModel.profile.skill.title)), step: .skill, id: "skill")
            summaryRow("Store", value: preferences.stores.isEmpty ? String(localized: "Sample grocery prices") : preferences.stores.map(\.label).sorted().joined(separator: ", "), step: .stores, id: "store")
            summaryRow("Dietary preferences", value: "\(viewModel.profile.preferences.count + (preferences.additionalDiets?.count ?? 0) + (preferences.keto ? 1 : 0)) selected", step: .diet, id: "diet")
            summaryRow("Food allergies", value: "\(viewModel.wholeAllergyGroups.count + (preferences.detailedAllergies?.count ?? 0)) selected", step: .allergies, id: "allergies")
            summaryRow("Goals", value: "\(preferences.goals.count) selected", step: .goals, id: "goals")
            summaryRow("Kitchen equipment", value: "\(preferences.equipment.intersection(KitchenEquipment.appliances).count) selected", step: .kitchen, id: "kitchen")
            summaryRow("Cooking styles", value: "\(preferences.styles.count) selected", step: .style, id: "style")
            DevelopmentNotice()
            if viewModel.nextCycle != nil {
                Button("Favorites and next-plan pins") { showingFavorites = true }
                    .frame(minHeight: 44)
            }
        }
    }

    private func summaryRow(_ title: LocalizedStringKey, value: String, step: OnboardingViewModel.Step, id: String) -> some View {
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
        ZStack {
            SetupFoodRain()
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(DesignTokens.action)
                Text("Building your meal plan")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Matching meals and checking grocery costs.")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 24))
            .padding(24)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("setup.loading")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.surface.ignoresSafeArea())
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
                                .accessibilityIdentifier("setup.preview.recipe")
                        }.padding(.vertical, 6)
                    }
                }
                Button("Accept new plan") { Task { await accept() } }.buttonStyle(MealWiseButtonStyle())
                Button("Edit answers") { viewModel.edit(.summary) }.buttonStyle(MealWiseButtonStyle(kind: .secondary))
                if isEditing { Button("Keep current plan") { dismiss() }.frame(minHeight: 44) }
            }.padding(22)
        }
    }

    private func accept() async {
        if let plan = await viewModel.acceptPreview() { session.accept(plan) }
    }
}

#Preview { RootView().environment(AppSession()) }
