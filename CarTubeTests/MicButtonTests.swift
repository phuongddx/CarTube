//
//  MicButtonTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class MicButtonTests: XCTestCase {

    private func makeButton() -> MicButton {
        MicButton(origin: .zero)
    }

    // Regression guard for CR-01: CarPlayViewController's onTouchUp calls
    // stopListening() then stopListeningVisuals() — a hint shown by onFailure inside
    // stopListening() must still be visible afterward.
    func testStopListeningVisualsPreservesAnActiveHintPill() {
        let button = makeButton()

        button.setListening(true)
        button.showHint(.noSpeech) {}

        XCTAssertFalse(button.pillBackground.isHidden, "showHint must make the pill visible")
        XCTAssertEqual(button.pillBackground.alpha, 1, accuracy: 0.001)

        button.stopListeningVisuals()

        XCTAssertFalse(button.pillBackground.isHidden, "stopListeningVisuals must never hide a hint pill shown in the same call stack")
        XCTAssertEqual(button.pillBackground.alpha, 1, accuracy: 0.001)
    }

    // Documents the pre-existing setListening(false) contract: it always resets the
    // pill, which is exactly why CR-01's fix routes touch-up through
    // stopListeningVisuals() instead.
    func testSetListeningFalseHidesAnyVisiblePill() {
        let button = makeButton()

        button.setListening(true)
        button.showHint(.unavailable) {}
        XCTAssertFalse(button.pillBackground.isHidden)

        button.setListening(false)

        XCTAssertTrue(button.pillBackground.isHidden)
    }

    func testShowHintMakesPillVisibleImmediately() {
        let button = makeButton()
        XCTAssertTrue(button.pillBackground.isHidden)

        button.showHint(.noSpeech) {}

        XCTAssertFalse(button.pillBackground.isHidden)
        XCTAssertEqual(button.pillBackground.alpha, 1, accuracy: 0.001)
    }

    func testShowHintDismissesAfterItsDisplayDurationAndInvokesOnDismiss() {
        let button = makeButton()
        let dismissed = expectation(description: "onDismiss invoked")

        button.showHint(.noSpeech) {
            dismissed.fulfill()
        }

        wait(for: [dismissed], timeout: 3.0)
        XCTAssertTrue(button.pillBackground.isHidden)
    }
}
