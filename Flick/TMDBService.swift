import Foundation

struct TMDBService {
    private static let base = "https://api.themoviedb.org/3"
    private static var headers: [String: String] {
        ["Authorization": "Bearer \(AppSettings.tmdbToken)"]
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    static func trending() async throws -> [MediaItem] {
        guard AppSettings.isTMDBConfigured else { throw APIError.notConfigured }
        var comps = URLComponents(string: "\(base)/trending/all/week")!
        comps.queryItems = [URLQueryItem(name: "region", value: "IE")]
        let page: TMDBPage = try await apiGet(comps.url!, headers: headers, decoder: decoder)
        return page.results
    }

    static func discover(kind: MediaKind, providerId: Int) async throws -> [MediaItem] {
        guard AppSettings.isTMDBConfigured else { throw APIError.notConfigured }
        let path = kind == .movie ? "movie" : "tv"
        var comps = URLComponents(string: "\(base)/discover/\(path)")!
        comps.queryItems = [
            URLQueryItem(name: "watch_region", value: "IE"),
            URLQueryItem(name: "with_watch_providers", value: "\(providerId)"),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "page", value: "1")
        ]
        let page: TMDBPage = try await apiGet(comps.url!, headers: headers, decoder: decoder)
        return page.results.map { item in
            // Discover endpoints don't return media_type, so inject it
            MediaItem(
                id: item.id,
                title: kind == .movie ? (item.title ?? item.name) : nil,
                name: kind == .tv ? (item.name ?? item.title) : nil,
                overview: item.overview,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath,
                voteAverage: item.voteAverage,
                releaseDate: kind == .movie ? item.releaseDate : nil,
                firstAirDate: kind == .tv ? item.firstAirDate : nil,
                mediaType: kind.rawValue
            )
        }
    }

    static func watchProviders(id: Int, kind: MediaKind) async throws -> TMDBWatchProviders {
        guard AppSettings.isTMDBConfigured else { throw APIError.notConfigured }
        let path = kind == .movie ? "movie" : "tv"
        let url = URL(string: "\(base)/\(path)/\(id)/watch/providers")!
        return try await apiGet(url, headers: headers, decoder: decoder)
    }

    static func externalIDs(tvId: Int) async throws -> TMDBExternalIDs {
        guard AppSettings.isTMDBConfigured else { throw APIError.notConfigured }
        let url = URL(string: "\(base)/tv/\(tvId)/external_ids")!
        return try await apiGet(url, headers: headers, decoder: decoder)
    }

    static func seasons(tvId: Int) async throws -> [TMDBSeason] {
        guard AppSettings.isTMDBConfigured else { throw APIError.notConfigured }
        let url = URL(string: "\(base)/tv/\(tvId)")!
        let info: TMDBSeasonInfo = try await apiGet(url, headers: headers, decoder: decoder)
        return info.seasons.filter { $0.isRegular }
    }
}
