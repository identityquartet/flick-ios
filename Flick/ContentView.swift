import SwiftUI

struct ContentView: View {
    @State private var discovery = DiscoveryViewModel()
    @State private var queue = QueueViewModel()

    var body: some View {
        TabView {
            DiscoveryView(vm: discovery)
                .tabItem { Label("Discover", systemImage: "popcorn") }

            QueueView(vm: queue)
                .tabItem { Label("Queue", systemImage: "arrow.down.circle") }
                .badge(queue.totalItems > 0 ? queue.totalItems : 0)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            await discovery.loadLibraries()
            await discovery.load(tab: .trending, kind: .movie)
        }
        .preferredColorScheme(.dark)
    }
}
