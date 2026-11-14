import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            if session.isLoading {
                ProgressView("Opening MealWise").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = session.errorMessage {
                ContentUnavailableView {
                    Label("Could not open MealWise", systemImage: "exclamationmark.triangle")
                } description: { Text(LocalizedStringKey(error)) } actions: {
                    Button("Retry") { Task { await session.load() } }
                        .buttonStyle(MealWiseButtonStyle())
                }
            } else if session.plan != nil {
                MainTabView()
            } else if let services = session.services {
                NavigationStack {
                    WelcomeView()
                        .navigationDestination(for: AppRoute.self) { _ in
                            OnboardingView(profile: session.draft ?? OnboardingViewModel.defaultProfile(), services: services)
                        }
                }
            }
        }
        .background(DesignTokens.surface)
        .task { await session.load() }
    }
}

#Preview { RootView().environment(AppSession()) }
