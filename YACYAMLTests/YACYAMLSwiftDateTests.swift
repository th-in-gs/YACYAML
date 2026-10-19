//
//  YACYAMLSwiftDateTests.swift
//  YACYAMLTests
//
//  Swift ports of the date (timestamp) tests in YACYAMLTests.m.
//

import XCTest

final class YACYAMLSwiftDateTests: YACYAMLSwiftTestCase {
    func testDateParsing() throws {
        let yaml = """
            canonical:           2001-12-15T02:59:43.1Z
            valid iso8601:       2001-12-14t21:59:43.10-05:00
            space separated:     2001-12-14 21:59:43.10 -5
            no time zone (Z):    2001-12-15 2:59:43.10
            half hour time zone: 2001-12-15 3:29:43.10+00:30
            date (00:00:00Z):    2002-12-14
            """

        let unarchived = unarchivedDictionary(yaml) as! [String: Any]

        XCTAssertEqual(unarchived.count, 6)
        for (key, value) in unarchived {
            let date = value as? Date
            XCTAssertNotNil(date, "\(key) should be a date, got \(value)")
            let interval = date?.timeIntervalSince1970
            XCTAssertTrue(interval == 1008385183.1 ||  // 2001-12-15 2:59:43.10
                          interval == 1039824000,      // 2002-12-14
                          "\(key): Unarchived object not equal to archived object")
        }
    }

    func testDateArchiving() throws {
        let testArray = [Date(timeIntervalSince1970: 1039824000),
                         Date(timeIntervalSince1970: 1008385183.1),
                         Date(timeIntervalSince1970: 1008385323.01)]

        let string: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: testArray)

        XCTAssertTrue(!string.isEmpty, "Zero-length archive string")

        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: string) as? [Date]

        XCTAssertEqual(unarchived?.map { $0.timeIntervalSince1970 }, testArray.map { $0.timeIntervalSince1970 },
                       "Unarchived object not equal to archived object")
    }

    func testDateArchivingMilliseconds() throws {
        // Fractions are zero-padded to three digits.
        XCTAssertEqual(archivedScalar(for: Date(timeIntervalSince1970: 1008385323.01)), "2001-12-15T03:02:03.010Z")
        // Dates before the reference date (2001-01-01) have negative reference intervals.
        XCTAssertEqual(archivedScalar(for: Date(timeIntervalSinceReferenceDate: -0.5)), "2000-12-31T23:59:59.500Z")
        XCTAssertEqual(archivedScalar(for: Date(timeIntervalSinceReferenceDate: -0.05)), "2000-12-31T23:59:59.950Z")
        // Fractions beyond milliseconds are rounded, not truncated.
        XCTAssertEqual(archivedScalar(for: Date(timeIntervalSinceReferenceDate: 100.1236)), "2001-01-01T00:01:40.124Z")
        XCTAssertEqual(archivedScalar(for: Date(timeIntervalSinceReferenceDate: 100.9994)), "2001-01-01T00:01:40.999Z")
        // A fraction that rounds up to 1000ms must carry into the seconds.
        XCTAssertEqual(archivedScalar(for: Date(timeIntervalSinceReferenceDate: 10.9996)), "2001-01-01T00:00:11Z")
        XCTAssertEqual(archivedScalar(for: Date(timeIntervalSinceReferenceDate: -10.0004)), "2000-12-31T23:59:50Z")
    }

    func testDateMillisecondRoundTrip() throws {
        for interval in [-0.5, -0.05, -10.0004, 10.9996, 30077983.1, -86400.001] {
            // Dates are archived to millisecond precision.
            let expected = (interval * 1000.0).rounded() / 1000.0
            let archive: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: [Date(timeIntervalSinceReferenceDate: interval)])
            let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: archive) as? [Date]
            XCTAssertEqual(unarchived?.count, 1, archive)
            XCTAssertEqual(unarchived?.first?.timeIntervalSinceReferenceDate ?? .nan, expected, accuracy: 0.0005, "Round trip of \(interval) via \(archive)")
        }
    }

    func testDateNegativeTimeZoneWithMinutes() throws {
        // 2001-12-15T02:59:43Z expressed in other zones.
        let expected = Date(timeIntervalSince1970: 1008385183)
        for string in ["2001-12-14T21:29:43-05:30",
                       "2001-12-15T03:29:43+00:30",
                       "2001-12-15T02:59:43-00:00"] {
            XCTAssertEqual(unarchivedScalar(string) as? Date, expected, string)
        }
    }

    func testDateParsingForms() throws {
        // Each form is checked against its own expected time (seconds since 1970).
        let expectations: [String: Double] = [
            // Canonical, ISO 8601, space separated, and no time zone (UTC) forms.
            "2001-12-15T02:59:43.1Z": 1008385183.1,
            "2001-12-14t21:59:43.10-05:00": 1008385183.1,
            "2001-12-14 21:59:43.10 -5": 1008385183.1,
            "2001-12-15 2:59:43.10": 1008385183.1,
            "2001-12-15 3:29:43.10+00:30": 1008385183.1,
            // Date only (midnight UTC).
            "2002-12-14": 1039824000,
            "1970-01-01": 0,
            "1900-01-01": -2208988800,
            // Single digit month, day and hour.
            "2001-1-2T3:04:05Z": 978404645,
            // Fractions.
            "2001-12-15T02:59:43Z": 1008385183,
            "2001-12-15T02:59:43.Z": 1008385183,
            "2001-12-15T02:59:43.123456Z": 1008385183.123456,
            // Leap day and range extremes.
            "2000-02-29T12:34:56Z": 951827696,
            "9999-12-31T23:59:59Z": 253402300799,
            // Time zone forms.
            "2001-12-15T02:59:43+00:00": 1008385183,
            "2001-12-15T05:59:43+3": 1008385183,
            "2001-12-14T21:59:43-05": 1008385183,
            "2001-12-15T08:29:43+05:30": 1008385183,
            "2001-12-14T22:29:43-04:30": 1008385183,
            "2001-12-15T02:59:43 Z": 1008385183,
            "2001-12-15T02:59:43\t+0": 1008385183,
            "2001-12-15T02:59:43-00:30": 1008386983,
            // Offsets that cross a day, month or year boundary.
            "2001-12-31T23:59:59-01:00": 1009846799,
            "2000-02-29T23:30:00-01:00": 951870600,
        ]

        for (string, expected) in expectations.sorted(by: { $0.key < $1.key }) {
            let date = unarchivedScalar(string) as? Date
            XCTAssertNotNil(date, "\(string) should parse as a date, got \(String(describing: unarchivedScalar(string)))")
            XCTAssertEqual(date?.timeIntervalSince1970 ?? .nan, expected, accuracy: 0.0000005, "Wrong time parsed from \(string)")
        }
    }

    func testNonDatesAreNotParsedAsDates() throws {
        for string in ["2001-12", "12:30:00", "2001/12/14", "20011214", "not-a-date", "2001-12-14-3"] {
            XCTAssertFalse(unarchivedScalar(string) is Date, "\(string) should not parse as a date")
        }
    }

    func testDateLikeStringsRoundTripAsStrings() throws {
        let strings = ["2001-12-14", "2001-12-15T02:59:43Z", "2001-12-14 21:59:43.10 -5"]
        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedString(withRootObject: strings) as String) as? [String]
        XCTAssertEqual(unarchived, strings, "Strings that look like dates should stay strings")
    }

    func testDateArchivingExactStrings() throws {
        let expectations: [(Double, String)] = [
            // Midnight UTC is written as a plain date.
            (0, "1970-01-01"),
            (1039824000, "2002-12-14"),
            (-2208988800, "1900-01-01"),
            // Otherwise a full UTC timestamp.
            (951827696, "2000-02-29T12:34:56Z"),
            (946684799, "1999-12-31T23:59:59Z"),
            (253402300799, "9999-12-31T23:59:59Z"),
            (-14182940, "1969-07-20T20:17:40Z"),
            (2147483648, "2038-01-19T03:14:08Z"),
            // Fractions, zero padded to three digits.
            (1008385183.1, "2001-12-15T02:59:43.100Z"),
            (1008385183.001, "2001-12-15T02:59:43.001Z"),
            (1008385183.999, "2001-12-15T02:59:43.999Z"),
            (-14182940.25, "1969-07-20T20:17:39.750Z"),
        ]

        for (interval, expected) in expectations {
            XCTAssertEqual(archivedScalar(for: Date(timeIntervalSince1970: interval)), expected, "Wrong archived form of \(interval)")
        }
    }

    func testDateArchivingMidnightWithFraction() throws {
        // A date at midnight UTC that has a fraction of a second must not be written as a plain date.
        XCTAssertEqual(archivedScalar(for: Date(timeIntervalSince1970: 1039824000.5)), "2002-12-14T00:00:00.500Z")
        XCTAssertEqual(archivedScalar(for: Date(timeIntervalSince1970: -0.001)), "1969-12-31T23:59:59.999Z")
    }

    func testDateArchivingFractionBoundaries() throws {
        // Reference-date based, so that expected fractions are exact in binary where possible.
        // Each pair: seconds since 2001-01-01T00:00:00Z, expected archived form.
        let cases: [(Double, String)] = [
            // Smallest and largest millisecond fractions.
            (0.001, "2001-01-01T00:00:00.001Z"),
            (0.999, "2001-01-01T00:00:00.999Z"),
            // Fractions that need padding.
            (0.01, "2001-01-01T00:00:00.010Z"),
            (0.1, "2001-01-01T00:00:00.100Z"),
            (0.5, "2001-01-01T00:00:00.500Z"),
            // Sub-millisecond values round to the nearest millisecond.
            (0.0004, "2001-01-01"),
            (0.0006, "2001-01-01T00:00:00.001Z"),
            (0.9994, "2001-01-01T00:00:00.999Z"),
            (0.9996, "2001-01-01T00:00:01Z"),
            // Rounding up carries through minute, hour, day and month boundaries. A carry that
            // lands exactly on midnight gives a plain date.
            (59.9996, "2001-01-01T00:01:00Z"),
            (3599.9996, "2001-01-01T01:00:00Z"),
            (86399.9996, "2001-01-02"),
            (2678399.9996, "2001-02-01"),
            // Fractions just before the midnight, which is written as a plain date.
            (86399.999, "2001-01-01T23:59:59.999Z"),
            (86400.001, "2001-01-02T00:00:00.001Z"),
            // Negative reference intervals (before 2001-01-01).
            (-0.001, "2000-12-31T23:59:59.999Z"),
            (-0.999, "2000-12-31T23:59:59.001Z"),
            (-0.0004, "2001-01-01"),
            (-0.0006, "2000-12-31T23:59:59.999Z"),
            (-0.9996, "2000-12-31T23:59:59Z"),
            (-86399.9996, "2000-12-31"),
            (-31622399.9996, "2000-01-01"),
            // Midnight with a fraction is not a plain date.
            (86400.5, "2001-01-02T00:00:00.500Z"),
            (-86399.5, "2000-12-31T00:00:00.500Z"),
        ]

        for (interval, expected) in cases {
            XCTAssertEqual(archivedScalar(for: Date(timeIntervalSinceReferenceDate: interval)), expected,
                           "Wrong archived form of reference interval \(interval)")
        }
    }

    func testDateFractionParsing() throws {
        // Fractions of any length. Each pair: scalar, expected seconds since 2001-12-15T02:59:43Z.
        let cases: [(String, Double)] = [
            ("2001-12-15T02:59:43.1Z", 0.1),
            ("2001-12-15T02:59:43.10Z", 0.1),
            ("2001-12-15T02:59:43.100Z", 0.1),
            ("2001-12-15T02:59:43.001Z", 0.001),
            ("2001-12-15T02:59:43.999Z", 0.999),
            ("2001-12-15T02:59:43.0Z", 0),
            ("2001-12-15T02:59:43.000Z", 0),
            ("2001-12-15T02:59:43.5", 0.5),
            ("2001-12-15T02:59:43.5+00:00", 0.5),
            ("2001-12-15 02:59:43.25 Z", 0.25),
            ("2001-12-15T02:59:43.0000001Z", 0.0000001),
            ("2001-12-15T02:59:43.123456789Z", 0.123456789),
            ("2001-12-14T21:59:43.5-05:00", 0.5),
            ("2001-12-15T08:29:43.5+05:30", 0.5),
            // A fraction does not alter the whole-second part, or leak into the next unit.
            ("2001-12-15T02:59:44.999Z", 1.999),
            ("2001-12-15T02:59:42.999Z", -0.001),
        ]

        let base = Date(timeIntervalSince1970: 1008385183)
        for (string, expected) in cases {
            let date = unarchivedScalar(string) as? Date
            XCTAssertNotNil(date, "\(string) should parse as a date, got \(String(describing: unarchivedScalar(string)))")
            XCTAssertEqual(date?.timeIntervalSince(base) ?? .nan, expected, accuracy: 0.0000005, "Wrong fraction parsed from \(string)")
        }
    }

    func testDateFractionRoundTripAtEveryMillisecond() throws {
        // All 1000 millisecond fractions, in a second of a pre-2001 date, a 2001 date, and a midnight.
        for base in [-86400.0, 978307200, 1039824000, -2208988800] {
            let dates = (0..<1000).map { Date(timeIntervalSince1970: base + Double($0) / 1000.0) }

            let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedString(withRootObject: dates) as String) as? [Date] ?? []
            XCTAssertEqual(unarchived.count, dates.count, "Base \(base)")

            for (ms, date) in unarchived.enumerated() {
                XCTAssertEqual(date.timeIntervalSince1970, base + Double(ms) / 1000.0, accuracy: 0.0005,
                               "Round trip failed for base \(base) plus \(ms) ms")
            }
        }
    }

    func testDateRoundTripBroad() throws {
        // A deterministic spread of dates, roughly 1906 to 2096, at millisecond precision.
        var intervals = [Double]()
        var state: UInt64 = 0x2545F4914F6CDD1D
        for _ in 0..<2000 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let fraction = Double(state >> 11) / Double(UInt64(1) << 53)
            intervals.append(((fraction * 6.0e9 - 3.0e9) * 1000.0).rounded() / 1000.0)
        }
        let dates = intervals.map { Date(timeIntervalSinceReferenceDate: $0) }

        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedString(withRootObject: dates) as String) as? [Date] ?? []
        XCTAssertEqual(unarchived.count, dates.count)

        for (date, interval) in zip(unarchived, intervals) {
            XCTAssertEqual(date.timeIntervalSinceReferenceDate, interval, accuracy: 0.0005, "Round trip failed for reference interval \(interval)")
        }
    }

    func testDateRoundTripInContainers() throws {
        let date = Date(timeIntervalSince1970: 1008385183.1)
        let midnight = Date(timeIntervalSince1970: 1039824000)
        let root: [AnyHashable: Any] = ["single": date,
                                        "midnight": midnight,
                                        "nested": ["array": [date, midnight]],
                                        date: "date as a key"]

        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedString(withRootObject: root) as String) as? [AnyHashable: Any] ?? [:]

        XCTAssertEqual((unarchived["single"] as? Date)?.timeIntervalSince1970 ?? .nan, 1008385183.1, accuracy: 0.0005)
        XCTAssertEqual((unarchived["midnight"] as? Date)?.timeIntervalSince1970 ?? .nan, 1039824000, accuracy: 0.0005)
        let nested = (unarchived["nested"] as? [String: Any])?["array"] as? [Date]
        XCTAssertEqual(nested?.count, 2)
        XCTAssertEqual(nested?.first?.timeIntervalSince1970 ?? .nan, 1008385183.1, accuracy: 0.0005)
        XCTAssertEqual(nested?.last?.timeIntervalSince1970 ?? .nan, 1039824000, accuracy: 0.0005)

        let keyDate = unarchived.keys.compactMap { $0.base as? Date }.first
        XCTAssertNotNil(keyDate, "A date used as a dictionary key should be unarchived as a date")
        XCTAssertEqual(keyDate.flatMap { unarchived[$0] } as? String, "date as a key")
    }

    func testDateRoundTripAsRootObject() throws {
        let date = Date(timeIntervalSince1970: 1008385183.1)
        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedString(withRootObject: date) as String) as? Date
        XCTAssertNotNil(unarchived, "Got \(String(describing: unarchived))")
        XCTAssertEqual(unarchived?.timeIntervalSince1970 ?? .nan, 1008385183.1, accuracy: 0.0005)
    }
}
