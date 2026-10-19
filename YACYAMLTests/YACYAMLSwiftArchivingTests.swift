//
//  YACYAMLSwiftArchivingTests.swift
//  YACYAMLTests
//
//  Swift ports of the basic archiving tests in YACYAMLTests.m.
//

import XCTest

final class YACYAMLSwiftArchivingTests: YACYAMLSwiftTestCase {
    func testLibYAMLParsing() {
        var parser = yaml_parser_t()
        var event = yaml_event_t()

        yaml_parser_initialize(&parser)

        let input = "[ 'one', 1.01, 1, YES, false ]"
        var sawError = false
        input.withCString { cString in
            cString.withMemoryRebound(to: yaml_char_t.self, capacity: strlen(cString)) { chars in
                yaml_parser_set_input_string(&parser, chars, strlen(cString))

                var done = false
                while !done {
                    if yaml_parser_parse(&parser, &event) != 0 {
                        done = (event.type == YAML_STREAM_END_EVENT)
                        yaml_event_delete(&event)
                    } else {
                        sawError = true
                        done = true
                    }
                }
            }
        }

        yaml_parser_delete(&parser)

        XCTAssertFalse(sawError, "YAML parsing produced unexpected errors")
    }

    func testFloatScalarArchiving() throws {
        let testArray: [Any] = [
            Float.pi,
            Double.pi,
            Float.greatestFiniteMagnitude,
            Double.infinity,
            -Double.infinity,
            Double.nan,
            kCFNumberPositiveInfinity as NSNumber,
            kCFNumberNegativeInfinity as NSNumber,
            kCFNumberNaN as NSNumber,
        ]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testArray)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as? [NSNumber]

        // A strict isEqual between the test array and the unarchived array doesn't return true, because the
        // floats can't round-trip through ASCII fully.  We also lose some type information, because YAML
        // doesn't explicitly encode e.g. float vs. double.  Nevertheless, the values are good enough for
        // use, as a comparison of their string representation will show.
        XCTAssertEqual(unarchived?.map { $0.stringValue },
                       testArray.map { ($0 as! NSNumber).stringValue },
                       "Equality check failed")
    }

    func testIntegerScalarArchiving() throws {
        let testArray: [Any] = [
            Int8.max, Int8.min,
            UInt8.max, UInt8.min,
            Int16.max, Int16.min,
            UInt16.max, UInt16.min,
            Int32.max, Int32.min,
            UInt32.max, UInt32.min,
            Int.max, Int.min,
            Int64.max, Int64.min,
            UInt.max, UInt.min,
            UInt64.max, UInt64.min,
        ]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testArray)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        assertEqualObjects(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data), testArray, "Unarchived object not equal to archived object")
    }

    func testBooleanArchiving() throws {
        let testArray = [true, false]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testArray)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as? [Bool], testArray, "Unarchived object not equal to archived object")
    }

    func testDataArchiving() throws {
        let bytes = Data(String(repeating: "123456789012345678901234567890123456789012345678901234567890", count: 20).utf8)
        let testDictionary = ["my data's key": bytes]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testDictionary)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as? [String: Data], testDictionary, "Unarchived object not equal to archived object")
    }

    func testBigStringArchiving() throws {
        let string = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum"
        let testDictionary = ["my string's key": string]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testDictionary)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as? [String: String], testDictionary, "Unarchived object not equal to archived object")
    }

    func testNullArchiving() throws {
        let testArray: [Any] = ["one", NSNull(), "two", NSNull()]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testArray)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        assertEqualObjects(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data), testArray, "Unarchived object not equal to archived object")
    }

    func testSetArchiving() throws {
        let testSet: Set<String> = ["one", "two", "three", "four", "two"]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testSet)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")
    }

    func testEmptyString() throws {
        let testArray = ["one", "", "", "three", "four"]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testArray)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as? [String], testArray, "Unarchived object not equal to archived object")
    }

    func testSimpleArrayArchiving() throws {
        let testArray = ["one", "two", "three with a space and a colon:"]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testArray)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as? [String], testArray, "Unarchived object not equal to archived object")
    }

    func testSimpleDictionaryArchiving() throws {
        let numbers = ["one", "two", "three"]
        let inner: [String: Any] = ["onekey": "one", "twokey": "two", "threekey": "three", "fourKey": numbers]
        // (An array as a key.)
        let testDictionary: [AnyHashable: Any] = ["onekey": "one", "twokey": "two", "threekey": "three", "fourKey": numbers,
                                                  "dict": inner, ["arrayThatIsAKey"]: ["array"]]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testDictionary)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        assertEqualObjects(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data), testDictionary, "Unarchived object not equal to archived object")
    }

    func testStringsVsScalars() throws {
        let testArray: [Any] = ["1", 1, "y", "true", true]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: testArray)

        XCTAssertTrue(!data.isEmpty, "Archived data unexpectedly zero length")

        assertEqualObjects(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data), testArray, "Unarchived object not equal to archived object")
    }

    // The same thing, with Apple's archiver.  (Its -initForWritingWithMutableData: is deprecated.)
    @available(*, deprecated)
    func testNSArchiverChars() {
        let data = NSMutableData()

        let archiver = NSKeyedArchiver(forWritingWith: data)

        let string = strdup("hello world")!
        defer { free(string) }
        var pointer: UnsafeMutablePointer<CChar>? = string
        archiver.encodeValue(ofObjCType: "*", at: &pointer)

        archiver.finishEncoding()

        XCTAssertTrue(data.length != 0, "Archived data unexpectedly zero length")

        let unarchiver = NSKeyedUnarchiver(forReadingWith: data as Data)

        var newString: UnsafeMutablePointer<CChar>? = nil
        unarchiver.decodeValue(ofObjCType: "*", at: &newString)

        XCTAssertTrue(newString != nil && strcmp(string, newString) == 0, "Unarchived object not equal to archived object")
    }

    func testChars() throws {
        let data = NSMutableData()

        let archiver: YACYAMLKeyedArchiver = YACYAMLKeyedArchiver(forWritingWith: data)

        let string = strdup("hello world")!
        defer { free(string) }
        var pointer: UnsafeMutablePointer<CChar>? = string
        archiver.encodeValue(ofObjCType: "*", at: &pointer)

        try archiver.finishEncoding()

        XCTAssertTrue(data.length != 0, "Archived data unexpectedly zero length")

        let unarchiver = try! XCTUnwrap(YACYAMLKeyedUnarchiver(forReadingFrom: data as Data))

        var newString: UnsafeMutablePointer<CChar>? = nil
        unarchiver.decodeValue(ofObjCType: "*", at: &newString)

        XCTAssertTrue(newString != nil && strcmp(string, newString) == 0, "Unarchived object not equal to archived object")
    }

    func testNilEncoding() throws {
        let object = NilSubobjectObject()
        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: object)

        XCTAssertTrue(data.count != 0, "Archived data unexpectedly zero length")

        let unarchivedObject = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as? NilSubobjectObject

        XCTAssertEqual(unarchivedObject?.decodedCorrectly, true, "Unarchived subobject not nil")
    }

    func testValueOfObjCTypeWidths() throws {
        // The values are chosen to need the whole width of each type: reading only part of
        // them (a char for a short, or an int for a long long) gives a different number.
        // Values with every bit set are no good for this, as they survive being narrowed
        // and then sign extended.
        // Each value is archived on its own, as unkeyed values at the top level are written
        // as separate YAML documents, and only the first would be read back.
        func roundTrip<T: FixedWidthInteger>(_ type: String, _ original: T, _ expectedYAML: String) throws {
            var value = original
            let data = NSMutableData()
            let archiver: YACYAMLKeyedArchiver = YACYAMLKeyedArchiver(forWritingWith: data)
            archiver.encodeValue(ofObjCType: type, at: &value)
            try archiver.finishEncoding()

            let archived = String(data: data as Data, encoding: .utf8)!
            XCTAssertTrue(archived.hasPrefix(expectedYAML), "Type \(type) was archived as \(archived), not \(expectedYAML)")

            var decoded: T = 0
            let unarchiver = try XCTUnwrap(YACYAMLKeyedUnarchiver(forReadingFrom: data as Data))
            unarchiver.decodeValue(ofObjCType: type, at: &decoded)
            XCTAssertEqual(decoded, original, "Type \(type)")
        }

        try roundTrip("c", Int8(-100), "-100")
        try roundTrip("s", Int16(-300), "-300")
        try roundTrip("i", Int32(-70000), "-70000")
        try roundTrip("q", -(Int64(1) << 40), "-1099511627776")
        try roundTrip("C", UInt8(200), "200")
        try roundTrip("S", UInt16(300), "300")
        try roundTrip("I", UInt32(3_000_000_000), "3000000000")
        try roundTrip("Q", UInt64(1) << 40, "1099511627776")
    }

    func testDecodeBytesWithNilLength() throws {
        // The length is allowed to be nil, if the caller doesn't need it (Swift imports the
        // parameter as optional).  A missing key gives nil (and a length of 0, if that's asked
        // for), with either.
        let archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: BytesObject())
        let decoded = try YACYAMLKeyedUnarchiver.unarchivedObject(from: archived) as? BytesObject
        XCTAssertNotNil(decoded, "Got \(String(describing: decoded)) from \(archived)")
        XCTAssertEqual(decoded?.decodedBytesWithNilLength, true)
        XCTAssertEqual(decoded?.decodedMissingBytesAsNil, true)
        XCTAssertEqual(decoded?.missingBytesLength, 0)
    }

    func testCStringEncodingAndDecoding() throws {
        // C strings (the '*' type) are written as data, with their terminating NUL, so that any
        // bytes can be encoded, not just valid UTF-8.
        let utf8: [CChar] = Array("caf\u{e9}".utf8CString)
        let notUTF8: [CChar] = [97, CChar(bitPattern: 0xFF), CChar(bitPattern: 0xFE), 98, 0]
        let empty: [CChar] = [0]
        for (index, bytes) in [utf8, notUTF8, empty].enumerated() {
            var string: UnsafeMutablePointer<CChar>? = bytes.withUnsafeBufferPointer { strdup($0.baseAddress!) }
            defer { free(string) }

            let data = NSMutableData()
            let archiver: YACYAMLKeyedArchiver = YACYAMLKeyedArchiver(forWritingWith: data)
            archiver.encodeValue(ofObjCType: "*", at: &string)
            try archiver.finishEncoding()

            var decoded: UnsafeMutablePointer<CChar>? = nil
            let unarchiver = try XCTUnwrap(YACYAMLKeyedUnarchiver(forReadingFrom: data as Data))
            unarchiver.decodeValue(ofObjCType: "*", at: &decoded)
            XCTAssertTrue(decoded != nil && strcmp(decoded, string) == 0, "String \(index) did not round trip")
        }

        // A NULL string can't be encoded.
        let archiver: YACYAMLKeyedArchiver = YACYAMLKeyedArchiver(forWritingWith: NSMutableData())
        // (The pointers for things that raise are allocated, and passed as they are, not as inout
        // arguments (&null): Swift keeps track of inout accesses, and an Objective-C exception that
        // unwinds through one leaves it recorded, which crashes the next time the variable is used.)
        let null = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: 1)
        null.initialize(to: nil)
        defer { null.deallocate() }
        let exception = YACYAMLSwiftCatchException { archiver.encodeValue(ofObjCType: "*", at: null) }
        XCTAssertEqual(exception?.name, .yacyamlUnsupportedObject)

        func decodeCString(from yaml: String) throws -> (string: String?, exception: NSException?) {
            let decoded = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: 1)
            decoded.initialize(to: nil)
            defer { decoded.deallocate() }
            let unarchiver = try XCTUnwrap(YACYAMLKeyedUnarchiver(forReadingFrom: Data(yaml.utf8)))
            let exception = YACYAMLSwiftCatchException { unarchiver.decodeValue(ofObjCType: "*", at: decoded) }
            return (decoded.pointee.map { String(cString: $0) }, exception)
        }

        // What's decoded always ends in a NUL, even if the YAML's data doesn't have one (here,
        // "abc" with nothing after it, and no bytes at all), so that a caller can use it as a C
        // string without reading off the end of it.  Hand-written strings are read as well.
        let yamlToExpected: [String: String] = ["!!binary YWJj": "abc",
                                                "!!binary YWJjAA==": "abc",
                                                "!!binary \"\"": "",
                                                "hello": "hello",
                                                "'caf\u{e9}'": "caf\u{e9}"]
        for (yaml, expected) in yamlToExpected {
            let result = try decodeCString(from: yaml)
            XCTAssertNil(result.exception, yaml)
            XCTAssertEqual(result.string, expected, "\(yaml) was decoded as \(String(describing: result.string))")
        }

        // Anything else can't be a C string.
        for yaml in ["[1, 2]", "{ a: b }"] {
            let result = try decodeCString(from: yaml)
            XCTAssertEqual(result.exception?.name, .yacyamlUnsupportedType, yaml)
        }
    }
}
