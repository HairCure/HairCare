
import SwiftUI

@main
struct Hair12App: App {
    @State private var store = AppDataStore()
    @State private var authVM = AuthViewModel()
    @State private var healthKit = HealthKitManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(store.hairInsightsStore)
                .environment(store.dietMateStore)
                .environment(store.mindEaseStore)
                .environment(authVM)
                .environment(healthKit)
                .preferredColorScheme(.light)
                .task {
                    await healthKit.requestAuthorization()
                    await NotificationManager.shared.requestPermission()
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification
                )) { _ in
                    Task {
                        await healthKit.refresh()
                        print("Refreshed on foreground")
                    }
                }
        }
    }
}
