import XCTest
@testable import ShiftLog

final class ShiftLogTests: XCTestCase {
    func testDayUsesAlmatyTimezone() {
        let date = ISO8601DateFormatter().date(from: "2026-10-01T20:30:00Z")!
        XCTAssertEqual(LocalDay.key(date), "2026-10-02")
    }
    func testTripEncodingPreservesRetryID() throws {
        let trip = Trip(id: "stable-id", start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 200), amount: 2400, payment: "card", commission: 360)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(Trip.self, from: encoder.encode(trip)), trip)
    }
    func testServerDatesWithAndWithoutFractionalSeconds() throws {
        for time in ["2026-10-01T08:10:00+05:00", "2026-10-01T08:10:00.123+05:00"] {
            let json = """
            {"date":"2026-10-01","timezone":"Asia/Almaty","summary":{"count":1,"revenue":2400,"commission":360,"net":2040,"cash":0,"card":2400},"trips":[{"id":"t1","start":"\(time)","end":"2026-10-01T09:00:00+05:00","amount":2400,"payment":"card","commission":360}]}
            """
            let day = try API.decodeDay(Data(json.utf8))
            XCTAssertEqual(day.trips.count, 1)
            XCTAssertEqual(LocalDay.key(day.trips[0].start), "2026-10-01")
        }
    }
}
