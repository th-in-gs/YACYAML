//
//  YACYAMLSwiftScalarTests.swift
//  YACYAMLTests
//
//  Swift ports of the scalar parsing and archiving tests (numbers, booleans, null, binary)
//  in YACYAMLTests.m.
//

import XCTest
import ImageIO

final class YACYAMLSwiftScalarTests: YACYAMLSwiftTestCase {
    func testPositiveIntegerParsing() throws {
        let integers = unarchivedDictionary("""
            canonical: 685230
            decimal: 685_230
            octal: 02472256
            hexadecimal: 0x_0A_74_AE
            binary: 0b1010_0111_0100_1010_1110
            sexagesimal: 190:20:30
            canonicalPlus: +685230
            decimalPlus: +685_230
            octalPlus: +02472256
            hexadecimalPlus: +0x_0A_74_AE
            binaryPlus: +0b1010_0111_0100_1010_1110
            sexagesimalPlus: +190:20:30

            """)

        XCTAssertEqual(integers.count, 12)
        for (key, value) in integers {
            XCTAssertEqual(value as? Int, 685230, "\(key): Unarchived object not equal to archived object")
        }
    }

    func testNegativeIntegerParsing() throws {
        let integers = unarchivedDictionary("""
            canonical: -685230
            decimal: -685_230
            octal: -02472256
            hexadecimal: -0x_0A_74_AE
            binary: -0b1010_0111_0100_1010_1110
            sexagesimal: -190:20:30

            """)

        XCTAssertEqual(integers.count, 6)
        for (key, value) in integers {
            XCTAssertEqual(value as? Int, -685230, "\(key): Unarchived object not equal to archived object")
        }
    }

    // The Objective-C version of this test has no newlines between the lines of its YAML, so it
    // decodes one string, and passes only because a string's -doubleValue reads its leading
    // number.  This one has them.  See ToDo.txt: the spec's own "exponentioal" example is not
    // matched by the YAML 1.1 float expression we use, and is left a string.
    func testPositiveFloatParsing() throws {
        let floats = unarchivedDictionary("""
            canonical: 6.8523015e+5
            exponentioal: 685.230_15e+03
            fixed: 685_230.15
            sexagesimal: 190:20:30.15

            """)

        XCTAssertEqual(floats.count, 4)
        for (key, value) in floats {
            if key as? String == "exponentioal" {
                XCTExpectFailure("The YAML 1.1 float expression rejects '_' after the decimal point (see ToDo.txt)") {
                    XCTAssertEqual(value as? Double, 685230.15, "\(key): Unarchived object not equal to archived object")
                }
            } else {
                XCTAssertEqual(value as? Double, 685230.15, "\(key): Unarchived object not equal to archived object")
            }
        }
    }

    func testNegativeFloatParsing() throws {
        let floats = unarchivedDictionary("""
            canonical: -6.8523015e+5
            exponentioal: -685.230_15e+03
            fixed: -685_230.15
            sexagesimal: -190:20:30.15

            """)

        XCTAssertEqual(floats.count, 4)
        for (key, value) in floats {
            if key as? String == "exponentioal" {
                XCTExpectFailure("The YAML 1.1 float expression rejects '_' after the decimal point (see ToDo.txt)") {
                    XCTAssertEqual(value as? Double, -685230.15, "\(key): Unarchived object not equal to archived object")
                }
            } else {
                XCTAssertEqual(value as? Double, -685230.15, "\(key): Unarchived object not equal to archived object")
            }
        }
    }

    func testSpecialFloatParsing() throws {
        let floats = unarchivedDictionary("""
            infinity: .INF
            positive infinity: +.INF
            negative infinity: -.inf
            not a number: .NaN

            """)

        let infinity = (floats["infinity"] as? Double) ?? 0
        XCTAssertTrue(infinity.isInfinite && infinity > 0, "Unarchived object not equal to archived object")

        let positiveInfinity = (floats["positive infinity"] as? Double) ?? 0
        XCTAssertTrue(positiveInfinity.isInfinite && positiveInfinity > 0, "Unarchived object not equal to archived object")

        let negativeInfinity = (floats["negative infinity"] as? Double) ?? 0
        XCTAssertTrue(negativeInfinity.isInfinite && negativeInfinity < 0, "Unarchived object not equal to archived object")

        XCTAssertTrue(((floats["not a number"] as? Double) ?? 0).isNaN, "Unarchived object not equal to archived object")
    }

    func testBooleanParsing() throws {
        // The YAML 1.1 boolean forms, in each of the three cases that YAML allows.
        let trueForms = ["true", "True", "TRUE", "yes", "Yes", "YES", "y", "Y", "on", "On", "ON"]
        let falseForms = ["false", "False", "FALSE", "no", "No", "NO", "n", "N", "off", "Off", "OFF"]

        for form in trueForms {
            let value = unarchivedScalar(form) as? NSNumber
            XCTAssertTrue(value != nil && CFGetTypeID(value!) == CFBooleanGetTypeID(), "\(form) should be a boolean, got \(String(describing: value))")
            XCTAssertEqual(value as? Bool, true, "\(form) should be true")
        }
        for form in falseForms {
            let value = unarchivedScalar(form) as? NSNumber
            XCTAssertTrue(value != nil && CFGetTypeID(value!) == CFBooleanGetTypeID(), "\(form) should be a boolean, got \(String(describing: value))")
            XCTAssertEqual(value as? Bool, false, "\(form) should be false")
        }

        // Other capitalisations, and near misses, are strings.
        for form in ["tRue", "TRUe", "fAlse", "FALSe", "yEs", "nO", "oN", "oFF", "truee", "fals", "ye", "t", "f", "o", "yes please"] {
            XCTAssertEqual(unarchivedScalar(form) as? String, form, "\(form) should be a string")
        }

        // Quoting, or an explicit string tag, makes them strings.
        XCTAssertEqual(unarchivedScalar("\"False\"") as? String, "False")
        XCTAssertEqual(unarchivedScalar("'yes'") as? String, "yes")
        XCTAssertEqual(unarchivedScalar("!!str true") as? String, "true")
    }

    func testBooleanLookingStringsRoundTrip() throws {
        // Strings that would be read back as booleans must be archived in a way that keeps them strings.
        // This is what keeps 'False' a string for other YAML parsers too, not just for this one.
        let strings = ["true", "True", "TRUE", "false", "False", "FALSE", "yes", "No", "y", "N", "on", "Off",
                       "tRue", "fAlse", "yes please"]

        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedString(withRootObject: strings) as String) as? [String]
        XCTAssertEqual(unarchived, strings)

        for string in ["True", "False", "FALSE"] {
            let archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: [string])
            XCTAssertTrue(archived.hasPrefix("- '"), "\(string) should be quoted when archived, got: \(archived)")
        }

        // And real booleans are archived as booleans.
        let booleans = [true, false]
        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedString(withRootObject: booleans) as String) as? [Bool], booleans)
    }

    func testFloatParsingForms() throws {
        // Each form is checked against its own expected value.  Each must be decoded as a float.
        let cases: [(String, Double)] = [
            ("1.5", 1.5),
            ("-1.5", -1.5),
            ("+1.5", 1.5),
            ("1.", 1),
            ("5.", 5),
            (".5", 0.5),
            ("+.5", 0.5),
            ("-.5", -0.5),
            ("0.0", 0),
            ("6.8523015e+5", 685230.15),
            ("685_230.15", 685230.15),
            ("1.5E-3", 0.0015),
            ("1.e+3", 1000),
            ("190:20:30.15", 685230.15),
            ("-190:20:30.15", -685230.15),
        ]

        for (string, expected) in cases {
            let value = unarchivedScalar(string)
            XCTAssertNotNil(value as? Double, "\(string) should be a number, got \(String(describing: value))")
            XCTAssertEqual(value as? Double ?? .nan, expected, accuracy: 0.0000005, "Wrong value for \(string)")
            XCTAssertEqual((value as? NSNumber).map { String(cString: $0.objCType) }, "d", "\(string) should be a double")
        }
    }

    func testMalformedFloatsAreStrings() throws {
        // These look a little like floats, but aren't.
        for string in ["1.5e", "1.5e+", "e+3", "1,5", "1.5f"] {
            XCTAssertEqual(unarchivedScalar(string) as? String, string, "\(string) should be a string")
        }

        // Strings that look like floats are archived in a way that keeps them strings, including ones
        // (like version numbers) that the YAML 1.1 float expression accepts but that aren't floats.
        let strings = [".", "1.2.3", "10.0.0.1", "1..2"]
        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedString(withRootObject: strings) as String) as? [String], strings)
    }

    func testHexadecimalAndBinaryIntegerParsing() throws {
        // 'b' is both the marker in a binary number (0b101) and a hexadecimal digit, which must not
        // confuse the two: hexadecimal numbers with a 'b' in them used to be decoded as 0.
        let cases: [(String, Int64)] = [
            ("0x1b", 27),
            ("0xb", 11),
            ("0xab", 171),
            ("0xAB", 171),
            ("0xbeef", 48879),
            ("-0xbeef", -48879),
            ("+0xbeef", 48879),
            ("0xdeadbeef", 3735928559),
            ("0x_0A_74_AE", 685230),
            ("0x_bb_bb", 48059),
            ("0b101", 5),
            ("-0b101", -5),
            ("+0b101", 5),
            ("0b_1_0", 2),
            ("0b1010_0111", 167),
            ("0", 0),
            ("0777", 511),
        ]

        for (string, expected) in cases {
            let value = unarchivedScalar(string)
            XCTAssertEqual(value as? Int64, expected, "Wrong value for \(string), got \(String(describing: value))")
        }
    }

    func testIntegerRangeParsing() throws {
        // Integers that fit in 64 bits (signed, or unsigned for large positive values) are numbers,
        // exactly.  Those that don't must not be silently clamped or wrapped.

        // Signed values.
        let signedCases: [(String, Int64)] = [
            ("9223372036854775807", 9223372036854775807),
            ("-9223372036854775808", Int64.min),
            ("-0x8000000000000000", Int64.min),
            ("0x7FFFFFFFFFFFFFFF", 9223372036854775807),
            ("-1", -1),
        ]
        for (string, expected) in signedCases {
            let value = unarchivedScalar(string)
            XCTAssertEqual(value as? Int64, expected, "Wrong value for \(string), got \(String(describing: value))")
        }

        // Positive values that need an unsigned 64 bit number.
        let unsignedCases = [
            "9223372036854775808",
            "18446744073709551615",
            "0xFFFFFFFFFFFFFFFF",
            "0b1111111111111111111111111111111111111111111111111111111111111111",
            "01777777777777777777777",
        ]
        for string in unsignedCases {
            let value = unarchivedScalar(string)
            XCTAssertEqual(value as? UInt64, string.count == 19 ? 9223372036854775808 : UInt64.max, "Wrong value for \(string), got \(String(describing: value))")
            // (Not "as? Double": Swift's cast from an NSNumber only succeeds if the double is exact, which
            // UInt64.max is not.  -doubleValue always works.)
            XCTAssertGreaterThan((value as? NSNumber)?.doubleValue ?? 0, 0, "\(string) should be positive")
        }

        // Too big for either.  These must not be clamped or wrapped: they are left as strings, so
        // that no information is lost.
        let tooBig = [
            "18446744073709551616",
            "99999999999999999999999999",
            "-9223372036854775809",
            "-99999999999999999999999999",
            "123456789012345678901234567890123456789",
            "1234567890123456789012345678901234567890123456789012345678901234567890",
            "0x10000000000000000",
            "-0x8000000000000001",
            "0b10000000000000000000000000000000000000000000000000000000000000000",
            "02000000000000000000000",
            "99999999999999999999:30",
        ]
        for string in tooBig {
            XCTAssertEqual(unarchivedScalar(string) as? String, string, "\(string) doesn't fit in 64 bits, so should be left as a string")
        }

        // And those strings survive being archived and unarchived.
        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedString(withRootObject: tooBig) as String) as? [String], tooBig)
    }

    func testFloatingPointNumbersAreArchivedAsFloats() throws {
        // A floating point number that happens to have a whole value must still be written so that
        // it is read back as a float: '1' would be read as an integer.  Each pair is the number
        // and how it's written.
        let cases: [(Double, String)] = [
            (1.0, "1.0"),
            (-1.0, "-1.0"),
            (0.0, "0.0"),
            (100000.0, "100000.0"),
            (123456789.0, "123456789.0"),
            (1e15, "1000000000000000.0"),
            (1e16, "1.0e+16"),
            (2.5e20, "2.5e+20"),
            (1e300, "1.0e+300"),
            (1e-5, "1.0e-05"),
            (1.5, "1.5"),
            (Double.pi, "3.141592653589793"),
            (1.5e300, "1.5e+300"),
        ]

        for (number, written) in cases {
            XCTAssertEqual(archivedScalar(for: number), written, "Wrong archived form of \(number)")

            let archive: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: [number])
            let unarchived = (try YACYAMLKeyedUnarchiver.unarchivedObject(from: archive) as! [NSNumber])[0]
            XCTAssertEqual(String(cString: unarchived.objCType), "d", "\(number) should come back as a double, not \(String(cString: unarchived.objCType))")
            XCTAssertEqual(unarchived.doubleValue, number, "Wrong value for \(number)")
        }

        // Negative zero.
        XCTAssertEqual(archivedScalar(for: -0.0), "-0.0")
        let negativeZeroArchive: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: [-0.0])
        let negativeZero = (try YACYAMLKeyedUnarchiver.unarchivedObject(from: negativeZeroArchive) as! [NSNumber])[0]
        XCTAssertTrue(negativeZero.doubleValue.sign == .minus, "Negative zero should stay negative")

        // Floats too.
        XCTAssertEqual(archivedScalar(for: Float(1.0)), "1.0")
        XCTAssertEqual(archivedScalar(for: Float(0.5)), "0.5")

        // Integers, booleans, infinities and NaN are as they were.
        XCTAssertEqual(archivedScalar(for: 1), "1")
        XCTAssertEqual(archivedScalar(for: -7), "-7")
        XCTAssertEqual(archivedScalar(for: Int64.min), "-9223372036854775808")
        XCTAssertEqual(archivedScalar(for: true), "true")
        XCTAssertEqual(archivedScalar(for: Double.infinity), ".inf")
        XCTAssertEqual(archivedScalar(for: -Double.infinity), "-.inf")
        XCTAssertEqual(archivedScalar(for: Double.nan), ".nan")

        // Decimal numbers are exact, not floating point, and are written as they always were.
        XCTAssertEqual(archivedScalar(for: NSDecimalNumber(string: "42")), "42")
        XCTAssertEqual(archivedScalar(for: NSDecimalNumber(string: "18446744073709551616")), "18446744073709551616")
    }

    func testExplicitFloatTag() {
        // A float tag makes a number a float, even if what it tags looks like an integer.
        for string in ["!!float 1", "!!float \"1\"", "!!float 0x01", "!!float +1"] {
            let value = unarchivedScalar(string) as? NSNumber
            XCTAssertNotNil(value, "\(string) should be a number, got \(String(describing: unarchivedScalar(string)))")
            XCTAssertEqual(value.map { String(cString: $0.objCType) }, "d", "\(string) should be a double")
            XCTAssertEqual(value as? Double, 1.0, "Wrong value for \(string)")
        }
        XCTAssertEqual(unarchivedScalar("!!float -3") as? Double, -3.0)
        XCTAssertEqual((unarchivedScalar("!!float -3") as? NSNumber).map { String(cString: $0.objCType) }, "d")
        XCTAssertEqual(unarchivedScalar("!!float 1.5") as? Double, 1.5)
        XCTAssertEqual(unarchivedScalar("!!float 190:20:30") as? Double, 685230.0)

        // Without the tag, they're integers.
        XCTAssertEqual((unarchivedScalar("1") as? NSNumber).map { String(cString: $0.objCType) }, "q")
        XCTAssertEqual((unarchivedScalar("!!int 1") as? NSNumber).map { String(cString: $0.objCType) }, "q")

        // Other tags that don't match what they tag are not errors: the value is left as a string.
        XCTAssertEqual(unarchivedScalar("!!bool maybe") as? String, "maybe")
        XCTAssertEqual(unarchivedScalar("!!int abc") as? String, "abc")
        XCTAssertEqual(unarchivedScalar("!!str 123") as? String, "123")
    }

    func testBinaryParsing() {
        // (A raw string, so that the backslashes at the ends of the lines in the first value are
        // YAML line continuations, not Swift escapes.)
        let binaryYAML = #"""
            canonical: !!binary "\
             R0lGODlhDAAMAIQAAP//9/X17unp5WZmZgAAAOfn515eXvPz7Y6OjuDg4J+fn5\
             OTk6enp56enmlpaWNjY6Ojo4SEhP/++f/++f/++f/++f/++f/++f/++f/++f/+\
             +f/++f/++f/++f/++f/++SH+Dk1hZGUgd2l0aCBHSU1QACwAAAAADAAMAAAFLC\
             AgjoEwnuNAFOhpEMTRiggcz4BNJHrv/zCFcLiwMWYNG84BwwEeECcgggoBADs="
            generic: !!binary |
             R0lGODlhDAAMAIQAAP//9/X17unp5WZmZgAAAOfn515eXvPz7Y6OjuDg4J+fn5
             OTk6enp56enmlpaWNjY6Ojo4SEhP/++f/++f/++f/++f/++f/++f/++f/++f/+
             +f/++f/++f/++f/++f/++SH+Dk1hZGUgd2l0aCBHSU1QACwAAAAADAAMAAAFLC
             AgjoEwnuNAFOhpEMTRiggcz4BNJHrv/zCFcLiwMWYNG84BwwEeECcgggoBADs=
            description:
             The binary value above is a tiny arrow encoded as a gif image.

            """#

        let unarchived = unarchivedDictionary(binaryYAML)

        let canonicalData = unarchived["canonical"] as? Data
        let genericData = unarchived["generic"] as? Data
        XCTAssertNotNil(canonicalData)
        XCTAssertEqual(canonicalData, genericData, "Unarchived object not equal to archived object")

        // Image validation using ImageIO (available on both macOS and iOS)
        let canonicalSource = canonicalData.flatMap { CGImageSourceCreateWithData($0 as CFData, nil) }
        let genericSource = genericData.flatMap { CGImageSourceCreateWithData($0 as CFData, nil) }

        XCTAssertNotNil(canonicalSource, "Failed to create image source from canonical data")
        XCTAssertNotNil(genericSource, "Failed to create image source from generic data")

        XCTAssertNotNil(canonicalSource.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }, "Failed to create image from canonical data")
        XCTAssertNotNil(genericSource.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }, "Failed to create image from generic data")
    }

    func testNullParsing() {
        let nulls = unarchivedDictionary("""
            empty:
            canonical: ~
            english: null
            ~: null key

            """)

        XCTAssertEqual(nulls["empty"] as? NSNull, NSNull(), "Unarchived object not equal to archived object")
        XCTAssertEqual(nulls["canonical"] as? NSNull, NSNull(), "Unarchived object not equal to archived object")
        XCTAssertEqual(nulls["english"] as? NSNull, NSNull(), "Unarchived object not equal to archived object")
        XCTAssertEqual(nulls[NSNull()] as? String, "null key", "Unarchived object not equal to archived object")
    }
}
