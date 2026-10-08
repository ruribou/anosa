import SwiftUI

@main
struct AnosaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.locationService)
        }
        .modelContainer(AppContainer.shared)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appDelegate.locationService.refresh()
            }
        }
    }
}
