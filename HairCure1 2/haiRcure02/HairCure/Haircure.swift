import SwiftUI
import BackgroundTasks
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct Hair12App: App {
    @State private var store = AppDataStore()
    @State private var authVM = AuthViewModel()
    @State private var healthKit = HealthKitManager.shared
    
    static let backgroundTaskIdentifier = "com.guavnish.hairCare.refreshTask"
    
    init() {
        let manager = HealthKitManager.shared
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundTaskIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            
            processingTask.expirationHandler = {
                processingTask.setTaskCompleted(success: false)
            }
            
            Task {
                // Run your background refresh work directly here
                await manager.refresh()
                processingTask.setTaskCompleted(success: true)
                
                Hair12App.scheduleBackgroundTask()
            }
        }
    }
    
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
                    
                    Hair12App.scheduleBackgroundTask()
                }
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
        }
    }
    
    static func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 mins later
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled successfully!")
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
}
