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

}
