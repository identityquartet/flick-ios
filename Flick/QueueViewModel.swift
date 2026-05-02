import SwiftUI

@MainActor
@Observable
class QueueViewModel {
    var radarrQueue: [RadarrQueueItem] = []
    var sonarrQueue: [SonarrQueueItem] = []
    var isLoading = false
    var errorMessage: String?
    var lastRefreshed: Date?

    func refresh() async {
        isLoading = true
        errorMessage = nil
        async let radarr: () = loadRadarr()
        async let sonarr: () = loadSonarr()
        _ = await (radarr, sonarr)
        lastRefreshed = Date()
        isLoading = false
    }

    private func loadRadarr() async {
        guard AppSettings.isRadarrConfigured else { return }
        do {
            let q = try await RadarrService.queue()
            radarrQueue = q.records
        } catch {
            errorMessage = "Radarr: \(error.localizedDescription)"
        }
    }

    private func loadSonarr() async {
        guard AppSettings.isSonarrConfigured else { return }
        do {
            let q = try await SonarrService.queue()
            sonarrQueue = q.records
        } catch {
            if errorMessage == nil {
                errorMessage = "Sonarr: \(error.localizedDescription)"
            }
        }
    }

    var isEmpty: Bool { radarrQueue.isEmpty && sonarrQueue.isEmpty }

    var totalItems: Int { radarrQueue.count + sonarrQueue.count }
}
