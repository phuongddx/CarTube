//
//  UtilitiesTests.swift
//  CarTubeTests
//
//  Created by Rory Madden on 5/1/2023.
//

import XCTest
@testable import CarTube

final class UtilitiesTests: XCTestCase {

    func testExtractVideoIDFromWatchURL() {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        XCTAssertEqual(extractYouTubeVideoID(url), "dQw4w9WgXcQ")
    }

    func testExtractVideoIDFromMobileWatchURL() {
        let url = "https://m.youtube.com/watch?v=dQw4w9WgXcQ"
        XCTAssertEqual(extractYouTubeVideoID(url), "dQw4w9WgXcQ")
    }

    func testExtractVideoIDFromYoutuBeURL() {
        let url = "https://youtu.be/dQw4w9WgXcQ"
        XCTAssertEqual(extractYouTubeVideoID(url), "dQw4w9WgXcQ")
    }

    func testExtractVideoIDFromEmbedURL() {
        let url = "https://www.youtube.com/embed/dQw4w9WgXcQ"
        XCTAssertEqual(extractYouTubeVideoID(url), "dQw4w9WgXcQ")
    }

    func testExtractVideoIDFromShortsURL() {
        let url = "https://www.youtube.com/shorts/dQw4w9WgXcQ"
        XCTAssertEqual(extractYouTubeVideoID(url), "dQw4w9WgXcQ")
    }

    func testExtractVideoIDFromNonLeadingQueryParam() {
        let url = "https://www.youtube.com/watch?list=PL123456789&v=dQw4w9WgXcQ"
        XCTAssertEqual(extractYouTubeVideoID(url), "dQw4w9WgXcQ")
    }

    func testExtractVideoIDFromNoCookieEmbedURL() {
        let url = "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"
        XCTAssertEqual(extractYouTubeVideoID(url), "dQw4w9WgXcQ")
    }

    func testExtractVideoIDWithHyphenAndUnderscore() {
        let url = "https://youtu.be/d-Qw4w9_gXc"
        XCTAssertEqual(extractYouTubeVideoID(url), "d-Qw4w9_gXc")
    }

    func testExtractVideoIDReturnsNilForNonYouTubeURL() {
        let url = "https://vimeo.com/12345"
        XCTAssertNil(extractYouTubeVideoID(url))
    }

    func testExtractVideoIDReturnsNilForPlainText() {
        let url = "hello world"
        XCTAssertNil(extractYouTubeVideoID(url))
    }

    func testExtractVideoIDReturnsNilForEmptyString() {
        let url = ""
        XCTAssertNil(extractYouTubeVideoID(url))
    }

    func testExtractVideoIDReturnsNilForTenCharacterID() {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXc"
        XCTAssertNil(extractYouTubeVideoID(url))
    }

    func testExtractVideoIDReturnsNilForTwelveCharacterID() {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQz"
        XCTAssertNil(extractYouTubeVideoID(url))
    }

}
