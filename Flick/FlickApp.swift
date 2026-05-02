import SwiftUI

@main
struct FlickApp: App {
    init() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        logInfo("App", "Flick v\(version) (\(build)) started")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
