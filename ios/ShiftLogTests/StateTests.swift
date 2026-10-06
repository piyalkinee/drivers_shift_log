import XCTest
@testable import ShiftLog

@MainActor
final class StateTests: XCTestCase {
    private func trip() -> Trip {
        Trip(id: "original-id", start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 200), amount: 2400, payment: "card", commission: 360)
    }
    func testRetryAfterRecreationPreservesPayloadAndServer() async {
        let suite = "ShiftLogTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = trip()
        let first = TripSubmission(defaults: defaults) { _, _ in throw URLError(.timedOut) }
        let success = await first.submit(original, serverURL: "https://original.test")
        XCTAssertFalse(success)
        XCTAssertEqual(first.pending?.trip, original)
        XCTAssertFalse(first.saving)
        let restored = TripSubmission(defaults: defaults) { trip, server in
            XCTAssertEqual(trip, original)
            XCTAssertEqual(server, "https://original.test")
        }
        var different = original; different.id = "new-id"; different.amount = 5000
        let retry = await restored.submit(different, serverURL: "https://other.test")
        XCTAssertTrue(retry)
        XCTAssertNil(restored.pending)
        XCTAssertNil(TripSubmission(defaults: defaults).pending)
    }
    func testValidationFailureUnlocksEditingButServerFailureKeepsRetry() async {
        for status in [400, 422, 409, 500] {
            let suite = "ShiftLogTests.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let model = TripSubmission(defaults: defaults) { _, _ in throw APIError(message: "failure", statusCode: status) }
            let result = await model.submit(trip(), serverURL: "https://shift.test")
            XCTAssertFalse(result)
            XCTAssertEqual(model.error, "failure")
            XCTAssertEqual(model.pending == nil, [400, 422].contains(status))
        }
    }
    func testCorruptOutboxDoesNotSendOrOverwrite() async {
        let suite = "ShiftLogTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let damaged = Data("damaged".utf8)
        defaults.set(damaged, forKey: "pendingTrip.v2")
        let model = TripSubmission(defaults: defaults) { _, _ in XCTFail("Must not send") }
        let result = await model.submit(trip(), serverURL: "https://shift.test")
        XCTAssertFalse(result)
        XCTAssertNotNil(model.error)
        XCTAssertEqual(defaults.data(forKey: "pendingTrip.v2"), damaged)
    }
    func testOlderResponseCannotReplaceSelectedDay() async throws {
        let model = DiaryModel()
        let started = expectation(description: "First request started")
        var continuation: CheckedContinuation<Day, Error>?
        let old = Task {
            await model.load(date: Date()) { _ in
                try await withCheckedThrowingContinuation { value in continuation = value; started.fulfill() }
            }
        }
        await fulfillment(of: [started], timeout: 2)
        let newDay = try API.decodeDay(Data(APITests.emptyDay.utf8))
        await model.load(date: Date()) { _ in newDay }
        let oldDay = try API.decodeDay(Data(APITests.emptyDay.replacingOccurrences(of: "2026-10-02", with: "2026-10-01").utf8))
        continuation?.resume(returning: oldDay)
        await old.value
        XCTAssertEqual(model.day?.date, "2026-10-02")
        XCTAssertFalse(model.loading)
    }
    func testLoadFailureClearsStaleDayAndCanRecover() async throws {
        let model = DiaryModel()
        let day = try API.decodeDay(Data(APITests.emptyDay.utf8))
        await model.load(date: Date()) { _ in day }
        await model.load(date: Date()) { _ in throw APIError(message: "offline") }
        XCTAssertNil(model.day)
        XCTAssertEqual(model.error, "offline")
        XCTAssertFalse(model.loading)
        await model.load(date: Date()) { _ in day }
        XCTAssertNil(model.error)
        XCTAssertEqual(model.day?.date, day.date)
    }
    func testServerConfiguration() {
        for url in ["https://api.example.org", "http://192.168.1.1:8080", " http://mac.local:8080/ "] {
            XCTAssertTrue(AppConfiguration.isValid(url), url)
        }
        for url in ["", "localhost", "ftp://host", "https://host/path", "https://host#fragment", "https://name:password@host"] {
            XCTAssertFalse(AppConfiguration.isValid(url), url)
        }
        XCTAssertEqual(AppConfiguration.normalized(" https://host/ "), "https://host")
    }
}
