//
//  YouTubeSearchServiceTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class YouTubeSearchServiceTests: XCTestCase {

    private func loadFixture(_ name: String) -> Data {
        let path = Bundle(for: YouTubeSearchServiceTests.self).path(forResource: name, ofType: "json")!
        return try! Data(contentsOf: URL(fileURLWithPath: path))
    }

    func testDecodingSearchResponseYieldsThreeResultsWithMatchingFirstElement() throws {
        let data = loadFixture("search-response")
        let results = try SearchResult.decodeSearchResponse(data)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].videoId, "dQw4w9WgXcQ")
        XCTAssertEqual(results[0].title, "Lofi Beats to Study To")
        XCTAssertEqual(results[0].channel, "Chillhop Music")
        XCTAssertEqual(results[0].thumbnail, URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"))
    }

    func testDecodingVideosResponseYieldsDurationsPerVideo() throws {
        let data = loadFixture("videos-response")
        let durations = try SearchResult.decodeDurationsByVideoId(data)

        XCTAssertEqual(durations["dQw4w9WgXcQ"], "PT4M13S")
        XCTAssertEqual(durations["jNQXAC9IVRw"], "PT1H2M9S")
        XCTAssertEqual(durations["9bZkp7q19f0"], "PT47S")
    }

    func testSnippetWithoutOptionalFieldsDecodesWithNilChannelAndThumbnail() throws {
        let json = """
        {
          "items": [
            {
              "id": { "videoId": "abc12345678" },
              "snippet": { "title": "No Channel Or Thumbnail" }
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let results = try SearchResult.decodeSearchResponse(data)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].videoId, "abc12345678")
        XCTAssertNil(results[0].channel)
        XCTAssertNil(results[0].thumbnail)
    }

    func testEmptyItemsSearchResponseDecodesToEmptyArray() throws {
        let json = """
        { "items": [] }
        """
        let data = Data(json.utf8)
        let results = try SearchResult.decodeSearchResponse(data)

        XCTAssertEqual(results, [])
    }
}
