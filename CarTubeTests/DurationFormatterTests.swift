//
//  DurationFormatterTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class DurationFormatterTests: XCTestCase {

    func testMinutesAndSecondsFormatsAsUnpaddedMinutesZeroPaddedSeconds() {
        XCTAssertEqual(DurationFormatter.display("PT12M34S"), "12:34")
        XCTAssertEqual(DurationFormatter.display("PT4M13S"), "4:13")
    }

    func testHoursMinutesSecondsFormatsWithZeroPaddedMinutesAndSeconds() {
        XCTAssertEqual(DurationFormatter.display("PT1H2M3S"), "1:02:03")
    }

    func testMissingComponentsDefaultToZero() {
        XCTAssertEqual(DurationFormatter.display("PT2H"), "2:00:00")
        XCTAssertEqual(DurationFormatter.display("PT58S"), "0:58")
        XCTAssertEqual(DurationFormatter.display("PT30S"), "0:30")
    }

    func testNilEmptyAndMalformedInputReturnNil() {
        XCTAssertNil(DurationFormatter.display(nil))
        XCTAssertNil(DurationFormatter.display(""))
        XCTAssertNil(DurationFormatter.display("12:34"))
        XCTAssertNil(DurationFormatter.display("garbage"))
        XCTAssertNil(DurationFormatter.display("P"))
    }
}
