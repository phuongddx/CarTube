//
//  YouTubeSearchServiceTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class YouTubeSearchServiceTests: XCTestCase {

    private let dummyKey = "dummy-test-key-not-real"

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func loadFixture(_ name: String) -> Data {
        let path = Bundle(for: YouTubeSearchServiceTests.self).path(forResource: name, ofType: "json")!
        return try! Data(contentsOf: URL(fileURLWithPath: path))
    }

    private func makeService(apiKey: String?) -> YouTubeSearchService {
        YouTubeSearchService(apiKey: apiKey, session: MockURLProtocol.makeSession())
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

    func testNormalizedKeyGateRejectsNilEmptyAndUnsubstitutedValues() {
        XCTAssertNil(YouTubeSearchService.normalizedKey(nil))
        XCTAssertNil(YouTubeSearchService.normalizedKey(""))
        XCTAssertNil(YouTubeSearchService.normalizedKey("$(YOUTUBE_API_KEY)"))
        XCTAssertEqual(YouTubeSearchService.normalizedKey(dummyKey), dummyKey)
    }

    func testSearchWithNilKeyThrowsApiKeyMissingAndIssuesZeroRequests() async {
        let service = makeService(apiKey: nil)

        do {
            _ = try await service.search(query: "lofi")
            XCTFail("Expected apiKeyMissing to be thrown")
        } catch let error as SearchError {
            XCTAssertEqual(error, .apiKeyMissing)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertTrue(MockURLProtocol.requestLog.isEmpty)
    }

    func testSearchWithUnsubstitutedOrEmptyKeyThrowsApiKeyMissingAndIssuesZeroRequests() async {
        for key in ["$(YOUTUBE_API_KEY)", ""] {
            MockURLProtocol.reset()
            let service = makeService(apiKey: key)

            do {
                _ = try await service.search(query: "lofi")
                XCTFail("Expected apiKeyMissing to be thrown for key: \(key)")
            } catch let error as SearchError {
                XCTAssertEqual(error, .apiKeyMissing)
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }

            XCTAssertTrue(MockURLProtocol.requestLog.isEmpty)
        }
    }

    func testSearchHappyPathFillsDurationsAndIssuesTwoCorrectlyShapedRequests() async throws {
        MockURLProtocol.responseQueue = [
            (200, loadFixture("search-response")),
            (200, loadFixture("videos-response"))
        ]
        let service = makeService(apiKey: dummyKey)

        let results = try await service.search(query: "lofi")

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].duration, "PT4M13S")
        XCTAssertEqual(results[1].duration, "PT1H2M9S")
        XCTAssertEqual(results[2].duration, "PT47S")

        XCTAssertEqual(MockURLProtocol.requestLog.count, 2)

        let firstURL = MockURLProtocol.requestLog[0].url!.absoluteString
        XCTAssertTrue(firstURL.contains("key="))
        XCTAssertTrue(firstURL.contains("type=video"))
        XCTAssertTrue(firstURL.contains("maxResults=10"))
        XCTAssertTrue(firstURL.contains("part=snippet"))

        let secondURL = MockURLProtocol.requestLog[1].url!.absoluteString
        XCTAssertTrue(secondURL.contains("key="))
        XCTAssertTrue(secondURL.contains("part=contentDetails,snippet"))
        XCTAssertTrue(secondURL.contains("id=dQw4w9WgXcQ,jNQXAC9IVRw,9bZkp7q19f0"))
    }

    func test403QuotaResponseMapsToSearchErrorQuotaExceeded() async {
        MockURLProtocol.responseQueue = [
            (403, loadFixture("error-403-quota"))
        ]
        let service = makeService(apiKey: dummyKey)

        do {
            _ = try await service.search(query: "lofi")
            XCTFail("Expected quotaExceeded to be thrown")
        } catch let error as SearchError {
            XCTAssertEqual(error, .quotaExceeded)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testEmptyItemsSearchResponseMapsToSuccessWithEmptyResultsAndNoFollowUpRequest() async throws {
        MockURLProtocol.responseQueue = [
            (200, loadFixture("search-response-empty"))
        ]
        let service = makeService(apiKey: dummyKey)

        let results = try await service.search(query: "obscure query with no results")

        XCTAssertEqual(results, [])
        XCTAssertEqual(MockURLProtocol.requestLog.count, 1)
    }

    func testNonQuotaHTTPErrorMapsToOtherDistinctFromQuota() async {
        MockURLProtocol.responseQueue = [
            (500, Data())
        ]
        let service = makeService(apiKey: dummyKey)

        do {
            _ = try await service.search(query: "lofi")
            XCTFail("Expected .other to be thrown")
        } catch let error as SearchError {
            if case .other = error {
                // expected
            } else {
                XCTFail("Expected .other, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTransportFailureMapsToOther() async {
        // No responses enqueued: MockURLProtocol fails the load with a URLError.
        let service = makeService(apiKey: dummyKey)

        do {
            _ = try await service.search(query: "lofi")
            XCTFail("Expected .other to be thrown")
        } catch let error as SearchError {
            if case .other = error {
                // expected
            } else {
                XCTFail("Expected .other, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testQueryWithSpacesAndAmpersandIsPercentEncodedInStubbedRequest() async throws {
        MockURLProtocol.responseQueue = [
            (200, loadFixture("search-response-empty"))
        ]
        let service = makeService(apiKey: dummyKey)

        _ = try await service.search(query: "lofi beats & focus")

        let requestURL = MockURLProtocol.requestLog[0].url!.absoluteString
        XCTAssertTrue(requestURL.contains("q=lofi%20beats%20%26%20focus"))
        XCTAssertFalse(requestURL.contains("lofi beats & focus"))
    }
}
