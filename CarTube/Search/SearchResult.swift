//
//  SearchResult.swift
//  CarTube
//

import Foundation

public struct SearchResult: Codable, Equatable {
    public let videoId: String
    public let title: String
    public let channel: String?
    public let thumbnail: URL?
    public let duration: String?
}

private struct SearchItemEnvelope: Codable {
    struct ID: Codable {
        let videoId: String
    }
    struct Snippet: Codable {
        struct Thumbnails: Codable {
            struct Thumbnail: Codable {
                let url: URL
            }
            let high: Thumbnail?
        }
        let title: String
        let channelTitle: String?
        let thumbnails: Thumbnails?
    }
    let id: ID
    let snippet: Snippet
}

private struct SearchResponseEnvelope: Codable {
    let items: [SearchItemEnvelope]
}

private struct VideoItemEnvelope: Codable {
    struct Snippet: Codable {
        let title: String
        let channelTitle: String?
    }
    struct ContentDetails: Codable {
        let duration: String
    }
    let id: String
    let snippet: Snippet
    let contentDetails: ContentDetails
}

private struct VideoResponseEnvelope: Codable {
    let items: [VideoItemEnvelope]
}

extension SearchResult {
    static func decodeSearchResponse(_ data: Data, durationsByVideoId: [String: String] = [:]) throws -> [SearchResult] {
        let envelope = try JSONDecoder().decode(SearchResponseEnvelope.self, from: data)
        return envelope.items.map { item in
            SearchResult(
                videoId: item.id.videoId,
                title: item.snippet.title,
                channel: item.snippet.channelTitle,
                thumbnail: item.snippet.thumbnails?.high?.url,
                duration: durationsByVideoId[item.id.videoId]
            )
        }
    }

    static func decodeDurationsByVideoId(_ data: Data) throws -> [String: String] {
        let envelope = try JSONDecoder().decode(VideoResponseEnvelope.self, from: data)
        var durations: [String: String] = [:]
        for item in envelope.items {
            durations[item.id] = item.contentDetails.duration
        }
        return durations
    }
}
