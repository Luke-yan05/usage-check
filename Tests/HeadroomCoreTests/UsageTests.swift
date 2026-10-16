import XCTest
@testable import HeadroomCore

final class UsageTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testCodexRemainingAndActualWindowDuration() throws {
        let json = #"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":23,"reset_at":1800010000,"limit_window_seconds":18000},"secondary_window":{"used_percent":100,"reset_at":1800050000,"limit_window_seconds":604800}}}"#
        let snapshot = try UsageParser.parse(Data(json.utf8), provider: .codex, now: now)
        XCTAssertEqual(snapshot.windows[0].remainingPercent(at: now), 77)
        XCTAssertEqual(snapshot.windows[0].title, "5-hour limit")
        XCTAssertEqual(snapshot.windows[1].title, "Weekly limit")
        XCTAssertEqual(snapshot.windows[1].remainingPercent(at: now), 0)
        XCTAssertFalse(snapshot.isStale(at: now))
        XCTAssertTrue(snapshot.isStale(at: now.addingTimeInterval(901)))
    }

    func testExpiredReadingDoesNotInventFullAllowance() throws {
        let json = #"{"rate_limit":{"primary_window":{"used_percent":90,"reset_at":1799999999}}}"#
        let snapshot = try UsageParser.parse(Data(json.utf8), provider: .codex, now: now)
        XCTAssertNil(snapshot.windows[0].remainingPercent(at: now))
        XCTAssertTrue(snapshot.isStale(at: now))
    }

    func testMissingAndNullWindowsAreUnknown() {
        for json in ["{}", #"{"rate_limit":null}"#, #"{"rate_limit":{"primary_window":null}}"#, #"{"five_hour":null,"seven_day":null}"#] {
            XCTAssertThrowsError(try UsageParser.parse(Data(json.utf8), provider: .codex))
            XCTAssertThrowsError(try UsageParser.parse(Data(json.utf8), provider: .claude))
        }
    }

    func testInvalidPercentagesAreRejectedAndZeroIsValid() throws {
        for value in ["-1", "101", "true", #""25""#, "null"] {
            let json = "{\"five_hour\":{\"utilization\":\(value)}}"
            XCTAssertThrowsError(try UsageParser.parse(Data(json.utf8), provider: .claude))
        }
        let snapshot = try UsageParser.parse(Data(#"{"five_hour":{"utilization":0}}"#.utf8), provider: .claude)
        XCTAssertEqual(snapshot.windows[0].remainingPercent(), 100)
        XCTAssertNil(snapshot.windows[0].resetsAt)
    }

    func testClaudeFractionalPercentAndBothDateFormats() throws {
        let json = #"{"five_hour":{"utilization":23.5,"resets_at":"2030-01-02T03:04:05.123Z"},"seven_day":{"utilization":41.2,"resets_at":"2030-01-05T00:00:00Z"},"seven_day_sonnet":{"utilization":10,"resets_at":null},"seven_day_opus":{"utilization":20}}"#
        let snapshot = try UsageParser.parse(Data(json.utf8), provider: .claude, now: now)
        XCTAssertEqual(snapshot.windows.count, 4)
        XCTAssertEqual(snapshot.windows[0].remainingPercent(at: now), 76.5)
        XCTAssertNotNil(snapshot.windows[0].resetsAt)
        XCTAssertNotNil(snapshot.windows[1].resetsAt)
        XCTAssertEqual(Set(snapshot.windows.map(\.id)).count, 4)
    }

    func testAdditionalCodexLimitsAndMalformedSibling() throws {
        let json = #"{"rate_limit":{"primary_window":{"used_percent":20},"secondary_window":{"used_percent":false}},"additional_rate_limits":[{"limit_name":"Model X","rate_limit":{"primary_window":{"used_percent":75,"limit_window_seconds":3600}}}]}"#
        let snapshot = try UsageParser.parse(Data(json.utf8), provider: .codex)
        XCTAssertEqual(snapshot.windows.count, 2)
        XCTAssertEqual(snapshot.windows[1].title, "Model X · 1-hour limit")
        XCTAssertEqual(snapshot.windows[1].remainingPercent(), 25)
    }

    func testCacheRoundTrip() throws {
        let snapshot = try UsageParser.parse(Data(#"{"seven_day":{"utilization":50}}"#.utf8), provider: .claude)
        XCTAssertEqual(try JSONDecoder().decode(UsageSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
    }
}
