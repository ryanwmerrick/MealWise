import SwiftUI

@main
struct MealWiseApp: App {
    @State private var session: AppSession

    init() {
        #if DEBUG
        if let name = ProcessInfo.processInfo.environment["MEALWISE_UI_TEST_STORE"],
           let id = UUID(uuidString: name) {
            let url = URL.temporaryDirectory.appending(path: "MealWise-\(id).store")
            _session = State(initialValue: AppSession(bootstrap: AppBootstrap(storeURL: url)))
            return
        }
        #endif
        _session = State(initialValue: AppSession())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(DesignTokens.action)
        }
    }
}
