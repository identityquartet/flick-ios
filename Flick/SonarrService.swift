import Foundation

struct SonarrService {
    private static var headers: [String: String] {
        ["X-Api-Key": AppSettings.sonarrAPIKey]
    }

    private static func url(_ path: String) throws -> URL {
        guard !AppSettings.sonarrURL.isEmpty else { throw APIError.notConfigured }
        guard let url = URL(string: AppSettings.sonarrURL.trimmingCharacters(in: .init(charactersIn: "/")) + path) else {
            throw APIError.notConfigured
        }
        return url
    }

    static func allSeries() async throws -> [SonarrSeries] {
        try await apiGet(try url("/api/v3/series"), headers: headers)
    }

    // Look up a series by TVDB ID via Sonarr's lookup endpoint
    static func lookup(tvdbId: Int) async throws -> [SonarrSeries] {
        var comps = URLComponents(url: try url("/api/v3/series/lookup"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "term", value: "tvdb:\(tvdbId)")]
        return try await apiGet(comps.url!, headers: headers)
    }

    static func addSeries(item: MediaItem, tvdbId: Int, monitoredSeasons: [Int]) async throws -> SonarrSeries {
        let profileId = AppSettings.sonarrProfileId
        let rootFolder = AppSettings.sonarrRootFolder
        guard profileId > 0, !rootFolder.isEmpty else { throw APIError.notConfigured }
        logInfo("Sonarr", "Adding series \"\(item.displayTitle)\" tvdbId=\(tvdbId) seasons=\(monitoredSeasons)")

        // Fetch series data from Sonarr lookup to get complete season list
        let results = try await lookup(tvdbId: tvdbId)
        guard let template = results.first else { throw APIError.badResponse(404) }

        let seasons: [SonarrSeasonPayload] = (template.seasons ?? []).map { season in
            SonarrSeasonPayload(
                seasonNumber: season.seasonNumber,
                monitored: monitoredSeasons.contains(season.seasonNumber)
            )
        }

        let payload = SonarrAddPayload(
            title: template.title,
            tvdbId: tvdbId,
            qualityProfileId: profileId,
            rootFolderPath: rootFolder,
            monitored: true,
            seasons: seasons,
            addOptions: .init(searchForMissingEpisodes: true, monitor: "none")
        )
        let result: SonarrSeries = try await apiPost(try url("/api/v3/series"), headers: headers, body: payload)
        logInfo("Sonarr", "Series added \"\(item.displayTitle)\" sonarrId=\(result.id)")
        return result
    }

    static func queue() async throws -> SonarrQueue {
        var comps = URLComponents(url: try url("/api/v3/queue"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "pageSize", value: "50"), URLQueryItem(name: "includeSeriesInformation", value: "true")]
        return try await apiGet(comps.url!, headers: headers)
    }

    static func qualityProfiles() async throws -> [QualityProfile] {
        try await apiGet(try url("/api/v3/qualityprofile"), headers: headers)
    }

    static func rootFolders() async throws -> [RootFolder] {
        try await apiGet(try url("/api/v3/rootfolder"), headers: headers)
    }
}
