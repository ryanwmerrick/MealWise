import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            WelcomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .shell: MainTabView()
                    }
                }
        }
    }
}

#Preview { RootView() }
