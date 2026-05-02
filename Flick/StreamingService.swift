import Foundation

// Streaming Availability API by Movie of the Night
// Docs: https://docs.movieofthenight.com
// Required API key from https://www.movieofthenight.com/about/api
struct StreamingService {
    private static let base = "https://api.movieofthenight.com/v4"
    private static var headers: [String: String] {
        ["X-API-Key": AppSettings.streamingAPIKey]
    }

    static var isConfigured: Bool { !AppSettings.streamingAPIKey.isEmpty }

    // Fetch top shows for a specific service in Ireland
    static func topShows(service: String, showType: String) async throws -> [StreamingShow] {
        guard isConfigured else { return [] }
        var comps = URLComponents(string: "\(base)/shows/top")!
        comps.queryItems = [
            URLQueryItem(name: "country", value: "ie"),
            URLQueryItem(name: "service", value: service),
            URLQueryItem(name: "show_type", value: showType)
        ]
        // /shows/top returns a plain array
        return try await apiGet(comps.url!, headers: headers)
    }

    // Fetch streaming availability for a specific title
    static func show(tmdbId: Int, kind: MediaKind) async throws -> StreamingShow? {
        guard isConfigured else { return nil }
        let typeStr = kind == .movie ? "movie" : "series"
        let url = URL(string: "\(base)/shows/\(typeStr)/\(tmdbId)")!
        return try? await apiGet(url, headers: headers)
    }
}
