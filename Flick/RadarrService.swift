import Foundation

struct RadarrService {
    private static var headers: [String: String] {
        ["X-Api-Key": AppSettings.radarrAPIKey]
    }

    private static func url(_ path: String) throws -> URL {
        guard !AppSettings.radarrURL.isEmpty else { throw APIError.notConfigured }
        guard let url = URL(string: AppSettings.radarrURL.trimmingCharacters(in: .init(charactersIn: "/")) + path) else {
            throw APIError.notConfigured
        }
        return url
    }

    static func allMovies() async throws -> [RadarrMovie] {
        try await apiGet(try url("/api/v3/movie"), headers: headers)
    }

    static func addMovie(item: MediaItem) async throws -> RadarrMovie {
        let profileId = AppSettings.radarrProfileId
        let rootFolder = AppSettings.radarrRootFolder
        guard profileId > 0, !rootFolder.isEmpty else { throw APIError.notConfigured }
        logInfo("Radarr", "Adding movie \"\(item.displayTitle)\" tmdbId=\(item.id)")
        let payload = RadarrAddPayload(
            title: item.displayTitle,
            tmdbId: item.id,
            qualityProfileId: profileId,
            rootFolderPath: rootFolder,
            monitored: true,
            addOptions: .init(searchForMovie: true)
        )
        let result: RadarrMovie = try await apiPost(try url("/api/v3/movie"), headers: headers, body: payload)
        logInfo("Radarr", "Movie added \"\(item.displayTitle)\" radarrId=\(result.id)")
        return result
    }

    static func queue() async throws -> RadarrQueue {
        var comps = URLComponents(url: try url("/api/v3/queue"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "pageSize", value: "50")]
        return try await apiGet(comps.url!, headers: headers)
    }

    static func qualityProfiles() async throws -> [QualityProfile] {
        try await apiGet(try url("/api/v3/qualityprofile"), headers: headers)
    }

    static func rootFolders() async throws -> [RootFolder] {
        try await apiGet(try url("/api/v3/rootfolder"), headers: headers)
    }
}
