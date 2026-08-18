//
//  MockURLProtocol.swift
//  CarTubeTests
//

import Foundation

final class MockURLProtocol: URLProtocol {
    static var requestLog: [URLRequest] = []
    static var responseQueue: [(statusCode: Int, data: Data)] = []

    static func reset() {
        requestLog = []
        responseQueue = []
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        MockURLProtocol.requestLog.append(request)

        guard !MockURLProtocol.responseQueue.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        let (statusCode, data) = MockURLProtocol.responseQueue.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
