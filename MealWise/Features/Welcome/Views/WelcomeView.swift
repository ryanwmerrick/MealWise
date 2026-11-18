import SwiftUI

struct WelcomeView: View {
    @State private var showingSavedData = false
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 40

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                brandmark.padding(.horizontal, DesignTokens.inset).padding(.top, DesignTokens.inset)
                WelcomeIllustration()
                welcomeCopy.padding(.horizontal, DesignTokens.inset).padding(.bottom, DesignTokens.inset)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .background(DesignTokens.welcomeSurface)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSavedData) { SettingsView() }
    }

    private var brandmark: some View {
        Image("IconLeaf")
            .foregroundStyle(DesignTokens.action)
            .frame(width: 46, height: 46)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(DesignTokens.action, lineWidth: 1.5))
            .accessibilityHidden(true)
    }

    private var welcomeCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("mealwise").font(.headline).foregroundStyle(DesignTokens.action)
            Text("Your money sets\nthe menu.")
                .font(.system(size: headlineSize, weight: .heavy))
                .tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Tell us your grocery budget. We’ll build a healthy week that fits it—and uses what you buy.")
                .font(.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(DesignTokens.textPrimary)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            NavigationLink(value: AppRoute.setup) {
                HStack {
                    Text("Plan my week")
                    Image("IconArrow").accessibilityHidden(true)
                }
            }
            .buttonStyle(MealWiseButtonStyle())
            .accessibilityIdentifier("welcome.start")
            Button("Saved data") { showingSavedData = true }
                .frame(minHeight: 44).accessibilityIdentifier("welcome.savedData")
            Text("No account. No payment. Just a plan.")
                .font(.footnote)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignTokens.inset)
        .padding(.vertical, 16)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.welcomeSurface)
    }
}

#Preview("Light") { NavigationStack { WelcomeView() }.environment(AppSession()) }
#Preview("Dark") { NavigationStack { WelcomeView() }.environment(AppSession()).preferredColorScheme(.dark) }
#Preview("Accessibility") { NavigationStack { WelcomeView() }.environment(AppSession()).dynamicTypeSize(.accessibility5) }
