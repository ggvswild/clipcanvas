import Foundation
import XCTest
@testable import ClipCanvasCore

final class RetentionPolicyTests: XCTestCase {
    func testRetentionCutoffsUseCalendarArithmetic() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01

        XCTAssertEqual(
            RetentionPeriod.day.cutoff(relativeTo: reference, calendar: calendar),
            calendar.date(byAdding: .day, value: -1, to: reference)
        )
        XCTAssertEqual(
            RetentionPeriod.week.cutoff(relativeTo: reference, calendar: calendar),
            calendar.date(byAdding: .day, value: -7, to: reference)
        )
        XCTAssertEqual(
            RetentionPeriod.month.cutoff(relativeTo: reference, calendar: calendar),
            calendar.date(byAdding: .month, value: -1, to: reference)
        )
        XCTAssertEqual(
            RetentionPeriod.year.cutoff(relativeTo: reference, calendar: calendar),
            calendar.date(byAdding: .year, value: -1, to: reference)
        )
        XCTAssertNil(RetentionPeriod.forever.cutoff(relativeTo: reference, calendar: calendar))
    }
}
