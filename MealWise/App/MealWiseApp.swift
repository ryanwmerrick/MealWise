import SwiftUI

@main
struct MealWiseApp: App {
    @State private var session = AppSession()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(DesignTokens.action)
        }
    }
}
