import SwiftUI

@main
struct AnosaWatchApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: WatchAppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(model: appDelegate.sync)
        }
    }
}
