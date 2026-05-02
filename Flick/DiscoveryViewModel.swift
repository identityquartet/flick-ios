import SwiftUI

@MainActor
@Observable
class DiscoveryViewModel {
    var selectedTab: DiscoveryTab = .trending
    var selectedKind: MediaKind = .movie

    var content: [MediaKind: [MediaItem]] = [.movie: [], .tv: []]
    var isLoading = false
    var errorMessage: String?

    // Library state — tmdbId sets
    var radarrLibrary: [Int: RadarrMovie] = [:]
    var sonarrLibrary: [Int: SonarrSeries] = [:]

    // Per-tab cached content keyed by (tab, kind)
    private var cache: [String: [MediaItem]] = [:]
    private var loadedTabs: Set<String> = []

    private func cacheKey(_ tab: DiscoveryTab, _ kind: MediaKind) -> String { "\(tab.id)-\(kind.rawValue)" }

    func load(tab: DiscoveryTab, kind: MediaKind) async {
        let key = cacheKey(tab, kind)
        if loadedTabs.contains(key) { return }
        isLoading = true
        errorMessage = nil
        do {
            let items = try await fetch(tab: tab, kind: kind)
            cache[key] = items
            loadedTabs.insert(key)
            content[kind] = items
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func switchTo(tab: DiscoveryTab, kind: MediaKind) {
        let key = cacheKey(tab, kind)
        if let cached = cache[key] {
            content[kind] = cached
        } else {
            Task { await load(tab: tab, kind: kind) }
        }
    }

    func refresh() {
        loadedTabs.removeAll()
        cache.removeAll()
        Task { await load(tab: selectedTab, kind: selectedKind) }
    }

    private func fetch(tab: DiscoveryTab, kind: MediaKind) async throws -> [MediaItem] {
        if tab == .trending {
            let all = try await TMDBService.trending()
            return all.filter { $0.kind == kind }
        }
        guard let providerId = tab.tmdbProviderId else { return [] }
        return try await TMDBService.discover(kind: kind, providerId: providerId)
    }

    // MARK: - Library

    func loadLibraries() async {
        async let radarr: () = loadRadarrLibrary()
        async let sonarr: () = loadSonarrLibrary()
        _ = await (radarr, sonarr)
    }

    private func loadRadarrLibrary() async {
        guard AppSettings.isRadarrConfigured else { return }
        if let movies = try? await RadarrService.allMovies() {
            radarrLibrary = Dictionary(uniqueKeysWithValues: movies.map { ($0.tmdbId, $0) })
        }
    }

    private func loadSonarrLibrary() async {
        guard AppSettings.isSonarrConfigured else { return }
        if let series = try? await SonarrService.allSeries() {
            sonarrLibrary = Dictionary(
                uniqueKeysWithValues: series.compactMap { s in s.tmdbId.map { ($0, s) } }
            )
        }
    }

    // MARK: - Status

    enum MediaStatus {
        case inLibrary, notInLibrary, notConfigured
    }

    func status(for item: MediaItem) -> MediaStatus {
        if item.kind == .movie {
            guard AppSettings.isRadarrConfigured else { return .notConfigured }
            return radarrLibrary[item.id] != nil ? .inLibrary : .notInLibrary
        } else {
            guard AppSettings.isSonarrConfigured else { return .notConfigured }
            return sonarrLibrary[item.id] != nil ? .inLibrary : .notInLibrary
        }
    }

    // MARK: - Add

    func addMovie(_ item: MediaItem) async throws {
        let movie = try await RadarrService.addMovie(item: item)
        radarrLibrary[movie.tmdbId] = movie
    }

    func addSeries(_ item: MediaItem, tvdbId: Int, seasons: [Int]) async throws {
        let series = try await SonarrService.addSeries(item: item, tvdbId: tvdbId, monitoredSeasons: seasons)
        if let tmdbId = series.tmdbId {
            sonarrLibrary[tmdbId] = series
        }
    }
}
