import AnosaKit
import SwiftUI

@main
struct AnosaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.locationService)
                .tint(AnosaTheme.accent)
        }
        .modelContainer(AppContainer.shared)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appDelegate.locationService.refresh()
            }
        }
    }
}
