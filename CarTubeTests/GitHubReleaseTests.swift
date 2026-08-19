//
//  GitHubReleaseTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class GitHubReleaseTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: GitHubReleaseTests.self)
        let path = try XCTUnwrap(bundle.path(forResource: "github-release", ofType: "json"))
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }

    private func fetch(statusCode: Int, body: Data) -> (data: Data?, response: URLResponse?) {
        MockURLProtocol.responseQueue = [(statusCode: statusCode, data: body)]
        let session = MockURLProtocol.makeSession()
        let requestDone = expectation(description: "request completes")
        var received: (data: Data?, response: URLResponse?) = (nil, nil)
        let task = session.dataTask(with: URL(string: "https://api.github.com/repos/example/example/releases/latest")!) { data, response, _ in
            received = (data, response)
            requestDone.fulfill()
        }
        task.resume()
        wait(for: [requestDone], timeout: 2)
        return received
    }

    func testValidReleaseFixtureDecodesTagName() throws {
        let (data, response) = fetch(statusCode: 200, body: try fixtureData())
        let release = GitHubRelease.validated(data: data, response: response)
        XCTAssertEqual(release?.tagName, "v9.9.9")
    }

    func testNon200StatusNeverProducesReleaseEvenWithValidBody() throws {
        let (data, response) = fetch(statusCode: 404, body: try fixtureData())
        XCTAssertNil(GitHubRelease.validated(data: data, response: response))
    }

    func testNewerTagIsDetectedAgainstInstalledVersion() {
        let release = GitHubRelease(tagName: "v9.9.9", body: nil)
        XCTAssertTrue(release.isNewer(than: "1.0.0"))
        XCTAssertFalse(release.isNewer(than: "v9.9.9"))
    }

    func testMissingTagNameFailsDecodeToNil() {
        let json = Data(#"{"name":"CarTube v9.9.9","body":"notes"}"#.utf8)
        let response = HTTPURLResponse(url: URL(string: "https://api.github.com/repos/example/example/releases/latest")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
        XCTAssertNil(GitHubRelease.validated(data: json, response: response))
    }

    func testAlertCopyNeverInterpolatesRemoteBody() {
        let sentinel = "INJECTED REMOTE TEXT"
        let release = GitHubRelease(tagName: "v9.9.9", body: sentinel)
        let copy = GitHubRelease.updateAlertBody(for: release)
        XCTAssertFalse(copy.contains(sentinel))
        XCTAssertTrue(copy.contains("v9.9.9"))
    }
}
