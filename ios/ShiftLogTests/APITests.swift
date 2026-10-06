import XCTest
@testable import ShiftLog

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class APITests: XCTestCase {
    private var session: URLSession!
    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: config)
    }
    override func tearDown() {
        session.invalidateAndCancel()
        StubURLProtocol.handler = nil
        super.tearDown()
    }
    func testDayRequestAndResponse() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://shift.test/api/day?date=2026-10-02")
            XCTAssertEqual(request.httpMethod, "GET")
            return (200, Data(Self.emptyDay.utf8))
        }
        let date = ISO8601DateFormatter().date(from: "2026-10-01T20:00:00Z")!
        let day = try await API(baseURL: "https://shift.test", session: session).day(date)
        XCTAssertEqual(day.date, "2026-10-02")
        XCTAssertEqual(day.summary.count, 0)
        XCTAssertTrue(day.trips.isEmpty)
    }
    func testPostUsesStableIDAndJSON() async throws {
        let trip = Trip(id: "stable", start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 200), amount: 2400, payment: "card", commission: 360)
        var ids: [String] = []
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/trips")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            var data = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(contentsOf: buffer.prefix(count))
                }
            }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let received = try decoder.decode(Trip.self, from: data)
            XCTAssertEqual(received, trip)
            ids.append(received.id)
            let response = "{\"trip\":\(String(data: data, encoding: .utf8)!),\"created\":\(ids.count == 1)}"
            return (ids.count == 1 ? 201 : 200, Data(response.utf8))
        }
        let api = API(baseURL: "https://shift.test", session: session)
        try await api.add(trip)
        try await api.add(trip)
        XCTAssertEqual(ids, ["stable", "stable"])
    }
    func testServerErrorPreservesStatusAndMessage() async {
        StubURLProtocol.handler = { _ in (409, Data("{\"error\":\"ID conflict\"}".utf8)) }
        do {
            _ = try await API(baseURL: "https://shift.test", session: session).day(Date())
            XCTFail("Expected conflict")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 409)
            XCTAssertEqual(error.message, "ID conflict")
        } catch { XCTFail("Unexpected error: \(error)") }
    }
    func testMalformedResponseAndTimeoutAreNotSuccess() async {
        for timeout in [false, true] {
            StubURLProtocol.handler = { _ in
                if timeout { throw URLError(.timedOut) }
                return (200, Data("not JSON".utf8))
            }
            do {
                _ = try await API(baseURL: "https://shift.test", session: session).day(Date())
                XCTFail("Expected failure")
            } catch { /* Both failures must reach the caller. */ }
        }
    }
    func testInvalidConfigurationDoesNotSendRequest() async {
        StubURLProtocol.handler = { _ in XCTFail("Must validate before network"); return (200, Data()) }
        for url in ["", "ftp://shift.test", "https://user:pass@shift.test", "https://shift.test/api", "https://shift.test?q=1"] {
            do {
                _ = try await API(baseURL: url, session: session).day(Date())
                XCTFail("Accepted \(url)")
            } catch { XCTAssertTrue(error is APIError) }
        }
    }
    func testAddRequiresMatchingConfirmation() async {
        let trip = Trip(id: "stable", start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 200), amount: 2400, payment: "card", commission: 360)
        for body in ["{}", "<html>OK</html>", "{\"created\":true,\"trip\":{\"id\":\"other\",\"start\":\"1970-01-01T00:01:40Z\",\"end\":\"1970-01-01T00:03:20Z\",\"amount\":2400,\"payment\":\"card\",\"commission\":360}}"] {
            StubURLProtocol.handler = { _ in (200, Data(body.utf8)) }
            do {
                try await API(baseURL: "https://shift.test", session: session).add(trip)
                XCTFail("Must not accept an unconfirmed write")
            } catch { /* Caller keeps its pending request. */ }
        }
    }
    static let emptyDay = """
    {"date":"2026-10-02","timezone":"Asia/Almaty","summary":{"count":0,"revenue":0,"commission":0,"net":0,"cash":0,"card":0},"trips":[]}
    """
}
