//
//  YouTubeSearchService.swift
//  CarTube
//

import Foundation

public enum SearchError: Error, Equatable {
    case apiKeyMissing
    case apiKeyInvalid
    case quotaExceeded
    case other(String)
}

public final class YouTubeSearchService {
    // Structural quota budget: exactly one page per search, no pagination parameter anywhere.
    private static let searchQueryBudget = "part=snippet&type=video&maxResults=10"

    // .urlQueryAllowed permits "&"/"="/"+" as unreserved query characters, which is
    // correct for a whole query string but wrong for a single value that must not
    // reintroduce delimiter characters (e.g. a query containing "&").
    private static let queryValueAllowedCharacters: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        return allowed
    }()

    private let apiKey: String?
    private let searchURL: String
    private let videosURL: String
    private let session: URLSession

    init(apiKey: String?, searchURL: String = YOUTUBE_SEARCH_ENDPOINT, videosURL: String = YOUTUBE_VIDEOS_ENDPOINT, session: URLSession = .shared) {
        self.apiKey = Self.normalizedKey(apiKey)
        self.searchURL = searchURL
        self.videosURL = videosURL
        self.session = session
    }

    public convenience init() {
        let rawKey = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String
        self.init(apiKey: rawKey)
    }

    static func normalizedKey(_ key: String?) -> String? {
        guard let key, !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }

    public func search(query: String) async throws -> [SearchResult] {
        guard let apiKey = self.apiKey else { throw SearchError.apiKeyMissing }

        let searchRequestURL = try Self.buildURL(
            base: searchURL,
            fixedQuery: Self.searchQueryBudget,
            values: [("q", query), ("key", apiKey)]
        )

        let (searchData, searchResponse) = try await performRequest(searchRequestURL)
        try Self.checkForAPIError(data: searchData, response: searchResponse)

        let results = try SearchResult.decodeSearchResponse(searchData)
        guard !results.isEmpty else { return [] }

        let videoIds = results.map(\.videoId)
        let videosRequestURL = try Self.buildURL(
            base: videosURL,
            fixedQuery: "part=contentDetails,snippet",
            values: [("id", videoIds.joined(separator: ",")), ("key", apiKey)]
        )

        let (videosData, videosResponse) = try await performRequest(videosRequestURL)
        try Self.checkForAPIError(data: videosData, response: videosResponse)

        let durationsByVideoId = try SearchResult.decodeDurationsByVideoId(videosData)
        return try SearchResult.decodeSearchResponse(searchData, durationsByVideoId: durationsByVideoId)
    }

    private func performRequest(_ url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(from: url)
        } catch {
            throw SearchError.other(error.localizedDescription)
        }
    }

    private static func buildURL(base: String, fixedQuery: String, values: [(name: String, value: String)]) throws -> URL {
        guard var components = URLComponents(string: base) else {
            throw SearchError.other("Invalid URL for \(base)")
        }

        let encodedPairs = values.map { name, value -> String in
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowedCharacters) ?? value
            return "\(name)=\(encodedValue)"
        }
        components.percentEncodedQuery = ([fixedQuery] + encodedPairs).joined(separator: "&")

        guard let url = components.url else {
            throw SearchError.other("Invalid URL for \(base)")
        }
        return url
    }

    private struct ErrorEnvelope: Codable {
        struct APIError: Codable {
            struct ErrorDetail: Codable {
                let reason: String
            }
            let errors: [ErrorDetail]
        }
        let error: APIError
    }

    private static func checkForAPIError(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 else { return }

        if httpResponse.statusCode == 403 {
            let reason = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.errors.first?.reason
            switch reason {
            case "quotaExceeded", "rateLimitExceeded", "dailyLimitExceeded":
                throw SearchError.quotaExceeded
            case "keyInvalid", "badRequest":
                throw SearchError.apiKeyInvalid
            default:
                throw SearchError.other("HTTP 403")
            }
        }

        throw SearchError.other("HTTP \(httpResponse.statusCode)")
    }
}
