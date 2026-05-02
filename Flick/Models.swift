import Foundation

// MARK: - Networking

enum APIError: LocalizedError {
    case notConfigured, badResponse(Int), decodingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Service URL or API key not configured in Settings."
        case .badResponse(let code): "Unexpected server response (\(code))."
        case .decodingFailed: "Failed to parse server response."
        }
    }
}

func apiGet<T: Decodable>(_ url: URL, headers: [String: String], decoder: JSONDecoder = JSONDecoder()) async throws -> T {
    var req = URLRequest(url: url)
    headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
    let (data, response) = try await URLSession.shared.data(for: req)
    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard 200..<300 ~= code else { throw APIError.badResponse(code) }
    do { return try decoder.decode(T.self, from: data) }
    catch { throw APIError.decodingFailed }
}

func apiPost<B: Encodable, T: Decodable>(_ url: URL, headers: [String: String], body: B, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONEncoder().encode(body)
    headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
    let (data, response) = try await URLSession.shared.data(for: req)
    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard 200..<300 ~= code else { throw APIError.badResponse(code) }
    do { return try decoder.decode(T.self, from: data) }
    catch { throw APIError.decodingFailed }
}

// MARK: - TMDB Models

enum MediaKind: String, Hashable {
    case movie, tv
}

struct MediaItem: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let releaseDate: String?
    let firstAirDate: String?
    let mediaType: String?

    var displayTitle: String { title ?? name ?? "Unknown" }
    var kind: MediaKind { (title != nil || mediaType == "movie") ? .movie : .tv }
    var year: Int? { (releaseDate ?? firstAirDate).flatMap { Int($0.prefix(4)) } }
    var rating: String { voteAverage.map { String(format: "%.1f", $0) } ?? "—" }
    var posterURL: URL? { posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") } }
    var backdropURL: URL? { backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w780\($0)") } }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool { lhs.id == rhs.id && lhs.kind == rhs.kind }
    func hash(into hasher: inout Hasher) { hasher.combine(id); hasher.combine(kind) }
}

struct TMDBPage: Codable {
    let results: [MediaItem]
}

struct TMDBWatchProviders: Codable {
    let results: [String: CountryProviders]

    struct CountryProviders: Codable {
        let flatrate: [Provider]?
        let rent: [Provider]?
        let buy: [Provider]?
    }

    struct Provider: Codable, Identifiable {
        let providerId: Int
        let providerName: String
        let logoPath: String?
        var id: Int { providerId }
        var logoURL: URL? { logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w45\($0)") } }
    }
}

struct TMDBExternalIDs: Codable {
    let tvdbId: Int?
    let imdbId: String?
}

struct TMDBSeasonInfo: Codable {
    let seasons: [TMDBSeason]
}

struct TMDBSeason: Codable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let episodeCount: Int?
    var isRegular: Bool { seasonNumber > 0 }
}

// MARK: - Radarr Models

struct RadarrMovie: Codable, Identifiable {
    let id: Int
    let title: String
    let tmdbId: Int
    let monitored: Bool
    let hasFile: Bool
    let status: String
}

struct RadarrAddPayload: Encodable {
    let title: String
    let tmdbId: Int
    let qualityProfileId: Int
    let rootFolderPath: String
    let monitored: Bool
    let addOptions: Options
    struct Options: Encodable { let searchForMovie: Bool }
}

struct RadarrQueue: Codable {
    let records: [RadarrQueueItem]
    let totalRecords: Int
}

struct RadarrQueueItem: Codable, Identifiable {
    let id: Int
    let title: String
    let status: String
    let sizeleft: Int64
    let size: Int64
    let timeleft: String?
    var progress: Double { size > 0 ? Double(size - sizeleft) / Double(size) : 0 }
    var progressText: String { String(format: "%.0f%%", progress * 100) }
}

struct RadarrCommand: Encodable {
    let name: String
    let movieIds: [Int]
}

struct RadarrCommandResponse: Decodable { let id: Int }

// MARK: - Sonarr Models

struct SonarrSeries: Codable, Identifiable {
    let id: Int
    let title: String
    let tmdbId: Int?
    let tvdbId: Int?
    let monitored: Bool
    let status: String
    let seasons: [SonarrSeason]?
}

struct SonarrSeason: Codable, Identifiable {
    let seasonNumber: Int
    let monitored: Bool
    let statistics: SonarrSeasonStats?
    var id: Int { seasonNumber }
    var isRegular: Bool { seasonNumber > 0 }
    var episodeCount: Int { statistics?.totalEpisodeCount ?? 0 }
}

struct SonarrSeasonStats: Codable {
    let totalEpisodeCount: Int
    let episodeFileCount: Int
}

struct SonarrAddPayload: Encodable {
    let title: String
    let tvdbId: Int
    let qualityProfileId: Int
    let rootFolderPath: String
    let monitored: Bool
    let seasons: [SonarrSeasonPayload]
    let addOptions: Options
    struct Options: Encodable {
        let searchForMissingEpisodes: Bool
        let monitor: String
    }
}

struct SonarrSeasonPayload: Encodable {
    let seasonNumber: Int
    let monitored: Bool
}

struct SonarrQueue: Codable {
    let records: [SonarrQueueItem]
    let totalRecords: Int
}

struct SonarrQueueItem: Codable, Identifiable {
    let id: Int
    let title: String
    let status: String
    let sizeleft: Int64
    let size: Int64
    let timeleft: String?
    let series: SonarrSeriesRef?
    var progress: Double { size > 0 ? Double(size - sizeleft) / Double(size) : 0 }
    var progressText: String { String(format: "%.0f%%", progress * 100) }
}

struct SonarrSeriesRef: Codable {
    let title: String
}

struct QualityProfile: Codable, Identifiable {
    let id: Int
    let name: String
}

struct RootFolder: Codable, Identifiable {
    let id: Int
    let path: String
}

// MARK: - Streaming Availability Models

struct StreamingShow: Codable {
    let tmdbId: String?
    let title: String
    let streamingOptions: [String: [StreamingOption]]?
    var irelandOptions: [StreamingOption] { streamingOptions?["ie"] ?? [] }
}

struct StreamingOption: Codable, Identifiable {
    let service: StreamingServiceInfo
    let type: String
    let link: String?
    var id: String { service.id + type }
}

struct StreamingServiceInfo: Codable {
    let id: String
    let name: String
}

// MARK: - Settings

enum AppSettings {
    private static let d = UserDefaults.standard

    static var radarrURL: String       { get { d.string(forKey: "radarrURL") ?? "" }      set { d.set(newValue, forKey: "radarrURL") } }
    static var radarrAPIKey: String    { get { d.string(forKey: "radarrAPIKey") ?? "" }    set { d.set(newValue, forKey: "radarrAPIKey") } }
    static var radarrProfileId: Int    { get { d.integer(forKey: "radarrProfileId") }      set { d.set(newValue, forKey: "radarrProfileId") } }
    static var radarrRootFolder: String { get { d.string(forKey: "radarrRootFolder") ?? "" } set { d.set(newValue, forKey: "radarrRootFolder") } }

    static var sonarrURL: String       { get { d.string(forKey: "sonarrURL") ?? "" }      set { d.set(newValue, forKey: "sonarrURL") } }
    static var sonarrAPIKey: String    { get { d.string(forKey: "sonarrAPIKey") ?? "" }    set { d.set(newValue, forKey: "sonarrAPIKey") } }
    static var sonarrProfileId: Int    { get { d.integer(forKey: "sonarrProfileId") }      set { d.set(newValue, forKey: "sonarrProfileId") } }
    static var sonarrRootFolder: String { get { d.string(forKey: "sonarrRootFolder") ?? "" } set { d.set(newValue, forKey: "sonarrRootFolder") } }

    static var tmdbToken: String       { get { d.string(forKey: "tmdbToken") ?? "" }       set { d.set(newValue, forKey: "tmdbToken") } }
    static var streamingAPIKey: String { get { d.string(forKey: "streamingAPIKey") ?? "" } set { d.set(newValue, forKey: "streamingAPIKey") } }

    static var isRadarrConfigured: Bool { !radarrURL.isEmpty && !radarrAPIKey.isEmpty }
    static var isSonarrConfigured: Bool { !sonarrURL.isEmpty && !sonarrAPIKey.isEmpty }
    static var isTMDBConfigured: Bool   { !tmdbToken.isEmpty }
}

// MARK: - Discovery Tabs

enum DiscoveryTab: String, CaseIterable, Identifiable {
    case trending = "Trending"
    case netflix = "Netflix"
    case prime = "Prime"
    case disney = "Disney+"
    case apple = "Apple TV+"

    var id: String { rawValue }

    var tmdbProviderId: Int? {
        switch self {
        case .trending: nil
        case .netflix: 8
        case .prime: 119
        case .disney: 337
        case .apple: 350
        }
    }

    var streamingServiceId: String? {
        switch self {
        case .trending: nil
        case .netflix: "netflix"
        case .prime: "prime"
        case .disney: "disney"
        case .apple: "apple"
        }
    }
}
