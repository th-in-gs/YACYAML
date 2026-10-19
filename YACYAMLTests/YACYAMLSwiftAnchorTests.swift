//
//  YACYAMLSwiftAnchorTests.swift
//  YACYAMLTests
//
//  Swift ports of the anchor, scalar-anchor, object-replacement and
//  DisallowInitWithCoder tests in YACYAMLTests.m.
//

import XCTest

final class YACYAMLSwiftAnchorTests: YACYAMLSwiftTestCase {
    func testAnchorGeneration() {
        let archiver: YACYAMLKeyedArchiver = YACYAMLKeyedArchiver(forWritingWith: NSMutableData())

        func skip(_ count: Int) {
            for _ in 0..<count {
                _ = archiver.generateAnchor()
            }
        }

        XCTAssertEqual("a", archiver.generateAnchor(), "Anchor generation generated unexpected result")
        XCTAssertEqual("b", archiver.generateAnchor(), "Anchor generation generated unexpected result")

        skip(24)

        XCTAssertEqual("A", archiver.generateAnchor(), "Anchor generation generated unexpected result")
        XCTAssertEqual("B", archiver.generateAnchor(), "Anchor generation generated unexpected result")

        skip(24)

        XCTAssertEqual("aa", archiver.generateAnchor(), "Anchor generation generated unexpected result")
        XCTAssertEqual("ab", archiver.generateAnchor(), "Anchor generation generated unexpected result")

        skip(24)

        XCTAssertEqual("aA", archiver.generateAnchor(), "Anchor generation generated unexpected result")
        XCTAssertEqual("aB", archiver.generateAnchor(), "Anchor generation generated unexpected result")

        skip(24)

        XCTAssertEqual("ba", archiver.generateAnchor(), "Anchor generation generated unexpected result")
        XCTAssertEqual("bb", archiver.generateAnchor(), "Anchor generation generated unexpected result")

        skip(24)

        XCTAssertEqual("bA", archiver.generateAnchor(), "Anchor generation generated unexpected result")
        XCTAssertEqual("bB", archiver.generateAnchor(), "Anchor generation generated unexpected result")

        skip(52)

        XCTAssertEqual("cC", archiver.generateAnchor(), "Anchor generation generated unexpected result")
        XCTAssertEqual("cD", archiver.generateAnchor(), "Anchor generation generated unexpected result")

        skip(52 * 52)

        XCTAssertEqual("acE", archiver.generateAnchor(), "Anchor generation generated unexpected result")
        XCTAssertEqual("acF", archiver.generateAnchor(), "Anchor generation generated unexpected result")
    }

    func testAnchorGenerationBoundaries() {
        // Anchors are a bijective base-52 encoding: 52 one-letter, then 52^2 two-letter,
        // then three-letter anchors starting at index 52 + 52^2 = 2756.
        let archiver: YACYAMLKeyedArchiver = YACYAMLKeyedArchiver(forWritingWith: NSMutableData())
        var seen = Set<String>()

        for i in 0..<60000 {
            let anchor: String = archiver.generateAnchor()

            if i == 2703 {
                XCTAssertEqual(anchor, "YZ", "Anchor at index 2703")
            } else if i == 2755 {
                XCTAssertEqual(anchor, "ZZ", "Last two-letter anchor")
            } else if i == 2756 {
                XCTAssertEqual(anchor, "aaa", "First three-letter anchor")
            }

            XCTAssertTrue(anchor.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) },
                          "Anchor \(i) (\(anchor)) contains a non-letter")
            XCTAssertFalse(seen.contains(anchor), "Anchor \(i) (\(anchor)) is a duplicate")
            seen.insert(anchor)
        }
    }

    func testScalarAnchorsOption() throws {
        // By default, scalars that are repeated are written out in full each time, for human
        // readability.  With YACYAMLKeyedArchiverOptionAllowScalarAnchors, they're written once, with
        // an anchor, and referred to by alias after that.
        let repeated = "a fairly long string that is repeated"
        let strings = [repeated, repeated, repeated, "a different string"]

        var archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: strings)
        XCTAssertFalse(archived.contains("&"), "No anchors expected by default: \(archived)")
        XCTAssertFalse(archived.contains("*"), "No aliases expected by default: \(archived)")

        archived = try YACYAMLKeyedArchiver.archivedString(withRootObject: strings, options: .allowScalarAnchors)
        XCTAssertTrue(archived.contains("&"), "Expected an anchor: \(archived)")
        XCTAssertEqual(archived.components(separatedBy: repeated).count, 2, "The string should be written once: \(archived)")
        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: archived) as? [String], strings, "Unarchived objects not equal to archived objects")

        // Scalars used as dictionary keys are anchored and referred to too.
        let key = "a key that is used more than once"
        let dictionaries = [[key: 1], [key: 2]]
        archived = try YACYAMLKeyedArchiver.archivedString(withRootObject: dictionaries, options: .allowScalarAnchors)
        XCTAssertEqual(archived.components(separatedBy: key).count, 2, "The key should be written once: \(archived)")
        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: archived) as? [[String: Int]], dictionaries)
    }

    func testScalarAnchorsOnlyWhenSmaller() throws {
        // With YACYAMLKeyedArchiverOptionAllowScalarAnchors, a repeated scalar is only given an anchor
        // when that makes the output smaller.  Written out in full each time, n uses of a scalar of
        // length l take n * l characters.  With an anchor, the first use is "&a " (the anchor name
        // is one character here) plus the scalar, and the rest are "*a": (1 + 2 + l) + (n - 1) * (1 + 1).
        // Each case is a scalar, how many times it's used, and whether that's enough for an anchor.
        let cases: [(value: Any, count: Int, expectAnchor: Bool)] = [
            // One character is never worth it, however many times it's used.
            ("x", 2, false),
            ("x", 100, false),
            // Three characters: 3n against 2n + 4, so it takes five uses.
            ("abc", 4, false),
            ("abc", 5, true),
            // Two uses: 5 characters is a tie (10 against 10), 6 is the first that wins (12 against 11).
            ("abcde", 2, false),
            ("abcdef", 2, true),
            // Longer strings are worth it from the second use.
            ("a fairly long string that is repeated", 2, true),
            ("a fairly long string that is repeated", 3, true),
            // As are numbers and booleans, by the same rule (and the length of what's written).
            (1000000, 3, true),
            (1, 50, false),
            (true, 2, false),
            (true, 3, true),
        ]

        for testCase in cases {
            let values = [Any](repeating: testCase.value, count: testCase.count)

            let archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: values, options: .allowScalarAnchors)
            let description = "\(testCase.value) used \(testCase.count) times \(testCase.expectAnchor ? "should" : "should not")"
            XCTAssertEqual(archived.contains("&"), testCase.expectAnchor, "\(description) have an anchor:\n\(archived)")
            XCTAssertEqual(archived.contains("*"), testCase.expectAnchor, "\(description) be referred to:\n\(archived)")
            assertEqualObjects(try YACYAMLKeyedUnarchiver.unarchivedObject(from: archived), values, "Unarchived objects not equal to archived objects")

            // The anchor is never used if it doesn't save space.
            let plain: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: values)
            XCTAssertLessThanOrEqual(archived.utf16.count, plain.utf16.count, "\(testCase.value) used \(testCase.count) times is longer with anchors")
        }

        // Objects that aren't scalars always get an anchor when they're used more than once,
        // however small, because that's how cycles are encoded.
        let shared = [1]
        let archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: [shared, shared], options: .allowScalarAnchors)
        XCTAssertTrue(archived.contains("&"), "A shared collection should have an anchor:\n\(archived)")
        XCTAssertTrue(archived.contains("*"), "A shared collection should be referred to:\n\(archived)")
    }

    func testScalarAnchorsKeepTypes() throws {
        // NSNumbers of different kinds compare as equal with isEqual: (1, 1.0 and true all do), but are
        // written differently, and are different when read back.  Using an anchor for one must not make
        // another of them the same type.
        let originals: [NSNumber] = [1, 1.0, true, 1, 1.0, true, 0, 0.0, false]

        let archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: originals, options: .allowScalarAnchors)
        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: archived) as? [NSNumber] ?? []

        XCTAssertEqual(unarchived.count, originals.count, archived)
        for (i, (original, value)) in zip(originals, unarchived).enumerated() {
            XCTAssertEqual(value, original, "Wrong value at \(i) in \(archived)")
            // The kind of number: a boolean, an integer (which is always read back as a long long, whatever
            // size it started as) or a floating point number.
            let originalIsBoolean = CFGetTypeID(original) == CFBooleanGetTypeID()
            let valueIsBoolean = CFGetTypeID(value) == CFBooleanGetTypeID()
            XCTAssertEqual(valueIsBoolean, originalIsBoolean, "Wrong boolean-ness at \(i) in \(archived)")
            if !originalIsBoolean {
                let originalIsFloat = ["d", "f"].contains(String(cString: original.objCType))
                let valueIsFloat = ["d", "f"].contains(String(cString: value.objCType))
                XCTAssertEqual(valueIsFloat, originalIsFloat, "Wrong kind of number at \(i) in \(archived)")
            }
        }

        // Equal numbers of the same kind are still shared.
        let same = [1000000, 1000000, 1000000]
        let archivedSame: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: same, options: .allowScalarAnchors)
        XCTAssertTrue(archivedSame.contains("*"), "Expected an alias: \(archivedSame)")
        XCTAssertEqual(try YACYAMLKeyedUnarchiver.unarchivedObject(from: archivedSame) as? [Int], same)
    }

    func testDisallowInitWithCoderOption() throws {
        // The option stops tagged classes being instantiated with initWithCoder:, so
        // YAML from an untrusted source can't make the unarchiver create arbitrary
        // objects. YACYAMLSwiftCapturingReplacingObject records the unarchiver when its
        // initWithCoder: runs, so YACYAMLSwiftCapturedUnarchiver being nil afterwards shows that
        // it was never called. The YAML has a tagged mapping for it, a tagged mapping
        // for a normal object, and a tagged sequence.
        let yaml = """
            - !YACYAMLSwiftCapturingReplacingObject
              child: hello
            - !YACYAMLSwiftNormalObject
              child: hello
            - !YACYAMLSwiftNormalObject [one, two]

            """

        // By default, tags name classes, which are instantiated with initWithCoder:.
        YACYAMLSwiftCapturedUnarchiver = nil
        var unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml) as! [Any]
        XCTAssertEqual(unarchived.count, 3)
        XCTAssertNotNil(YACYAMLSwiftCapturedUnarchiver, "initWithCoder: should be called by default")
        XCTAssertTrue(unarchived[1] is NormalObject, "Got \(unarchived[1])")
        YACYAMLSwiftCapturedUnarchiver = nil

        // With the option, they are presented as plain collections, and initWithCoder: is never called.
        let expected: [Any] = [["child": "hello"], ["child": "hello"], ["one", "two"]]

        unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml, options: .disallowInitWithCoder) as! [Any]
        assertEqualObjects(unarchived, expected)
        XCTAssertNil(YACYAMLSwiftCapturedUnarchiver, "initWithCoder: must not be called with the option set")

        // The same again, through the Data entry point.  The String method above
        // is a wrapper around this one, so this mainly guards the Data method
        // itself.  'data' is also used by the Data convenience methods below.
        let data = yaml.data(using: .utf8)!
        unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data, options: .disallowInitWithCoder) as! [Any]
        assertEqualObjects(unarchived, expected)
        XCTAssertNil(YACYAMLSwiftCapturedUnarchiver)

        // The String and Data convenience methods set the option, except for -YACYAMLDecodeAll.
        assertEqualObjects(try yaml.yacyamlDecode(), expected)
        assertEqualObjects(try yaml.yacyamlDecodeBasic(), expected)
        assertEqualObjects(try (data as NSData).yacyamlDecode(), expected)
        assertEqualObjects(try (data as NSData).yacyamlDecodeBasic(), expected)
        XCTAssertNil(YACYAMLSwiftCapturedUnarchiver)

        unarchived = try yaml.yacyamlDecodeAll() as! [Any]
        XCTAssertTrue(unarchived[1] is NormalObject, "Got \(unarchived[1])")
        XCTAssertNotNil(YACYAMLSwiftCapturedUnarchiver)
        YACYAMLSwiftCapturedUnarchiver = nil
    }

    func testArchiverDisallowLocalTagsOption() throws {
        // The option stops anything with a local tag (one that starts with a single '!', like
        // the !ClassName that application objects are written with) being archived, so that it
        // can't get into the output by accident.  YAML's own types, which have global tags,
        // are still written.
        let normal = NormalObject()
        normal.child = "hello"

        // By default, the object is written, tagged with its class.
        let archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: [normal])
        XCTAssertTrue(archived.contains("!YACYAMLSwiftNormalObject"), "Got \(archived)")

        // With the option, it throws, wherever the object is: at the top, in a collection, as a
        // dictionary value, or as a dictionary key (an NSURL, for this one, as keys have to be
        // hashable).  Classes that give themselves a local tag are refused too.
        let options: YACYAMLKeyedArchiverOptions = [.disallowLocalTags]
        let unencodable: [Any] = [normal,
                                  [normal],
                                  ["key": normal],
                                  [NSURL(string: "http://example.com/")!: "value"] as [AnyHashable: Any],
                                  LocalTagObject()]
        for object in unencodable {
            XCTAssertThrowsError(try YACYAMLKeyedArchiver.archivedString(withRootObject: object, options: options),
                                 "Should not have been able to archive \(object)") { error in
                // The code that NSKeyedArchiver uses for something that can't be written, with the
                // YACYAML error underneath.
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
                XCTAssertEqual(nsError.code, CocoaError.coderInvalidValue.rawValue)
                XCTAssertEqual((nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.code, YACYAMLError.unsupported.rawValue)
            }
        }

        // Nothing has been written to the data when it fails: the exception comes before
        // anything is output.
        let data = NSMutableData()
        let archiver = YACYAMLKeyedArchiver(forWritingWith: data, options: options)
        let exception = YACYAMLSwiftCatchException { archiver.encodeRootObject(["fine", normal]) }
        XCTAssertEqual(exception?.name, .yacyamlUnsupportedObject)
        XCTAssertEqual(data.length, 0)

        // YAML's own types are written exactly as they are without the option, including
        // the ones that are not scalars, and null.
        let native: [Any] = ["string", 1, 2.5, true, NSNull(),
                             Date(timeIntervalSinceReferenceDate: 0),
                             Data("abc".utf8),
                             ["nested", ["a": "b"]],
                             Set(["member"])]
        let withoutOption: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: native)
        var withOption: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: native, options: options)
        XCTAssertEqual(withOption, withoutOption)

        // Classes that give themselves a global tag are allowed too.
        withOption = try YACYAMLKeyedArchiver.archivedString(withRootObject: [GlobalTagObject()], options: options)
        XCTAssertTrue(withOption.contains("tag:example.com,2026:global"), "Got \(withOption)")

        // The option combines with the others.
        let repeated = "repeated string for anchoring"
        withOption = try YACYAMLKeyedArchiver.archivedString(withRootObject: [repeated, repeated, repeated],
                                                             options: [.disallowLocalTags, .allowScalarAnchors])
        XCTAssertTrue(withOption.contains("&"), "Got \(withOption)")
    }

    func testUnarchiverDisallowLocalTagsOption() throws {
        // The option makes the unarchiver ignore local tags (the ones that start with a single
        // '!'), so they never cause a class to be instantiated: what has one is read as if it
        // had no tag.  Global tags, like !!int, which is tag:yaml.org,2002:int, are still honoured.
        // YACYAMLSwiftCapturingReplacingObject records the unarchiver when its initWithCoder: runs,
        // so YACYAMLSwiftCapturedUnarchiver being nil afterwards shows that it was never called.
        let yaml = """
            - !YACYAMLSwiftCapturingReplacingObject
              child: hello
            - !YACYAMLSwiftNormalObject [one, two]
            - !NotAClass 12
            - !!int "5"
            - !!str 6

            """

        // By default, tags name classes, which are instantiated with initWithCoder:.
        YACYAMLSwiftCapturedUnarchiver = nil
        var unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml) as! [Any]
        XCTAssertEqual(unarchived.count, 5)
        XCTAssertNotNil(YACYAMLSwiftCapturedUnarchiver, "initWithCoder: should be called by default")
        XCTAssertTrue(unarchived[1] is NormalObject, "Got \(unarchived[1])")
        YACYAMLSwiftCapturedUnarchiver = nil

        // With the option, the local tags are ignored (a scalar with an ignored tag is left as a
        // string, not resolved as a number), and the global ones are used.
        let expected: [Any] = [["child": "hello"], ["one", "two"], "12", 5, "6"]
        unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml, options: [.disallowLocalTags]) as! [Any]
        assertEqualObjects(unarchived, expected)
        XCTAssertNil(YACYAMLSwiftCapturedUnarchiver, "initWithCoder: must not be called with the option set")

        // The same through the Data entry point, and combined with the other option.
        let data = yaml.data(using: .utf8)!
        unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data, options: [.disallowLocalTags, .disallowInitWithCoder]) as! [Any]
        assertEqualObjects(unarchived, expected)
        XCTAssertNil(YACYAMLSwiftCapturedUnarchiver)

        // Output from the archiver with the same option is read back by an unarchiver with it.
        let native: [Any] = ["string", 1, ["a": [2.5, NSNull()]]]
        let archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: native, options: [.disallowLocalTags])
        assertEqualObjects(try YACYAMLKeyedUnarchiver.unarchivedObject(from: archived, options: [.disallowLocalTags]), native)
    }

    func testDisallowInitWithCoderOptionStillDecodesYAMLTypes() throws {
        // The option only stops initWithCoder: being called on tagged classes. The
        // YAML types themselves must still decode to their Cocoa equivalents. (The
        // null key is called 'nothing' because a plain 'null' key would itself be YAML
        // null.)
        let yaml = """
            string: text
            integer: 42
            float: 1.5
            boolean: y
            nothing: ~
            date: 2001-12-15T02:59:43Z
            binary: !!binary aGVsbG8=
            sequence: [a, b]
            mapping: { key: value }
            set: !!set { a, b }

            """

        let unarchived = try yaml.yacyamlDecode() as! [String: Any]

        XCTAssertEqual(unarchived["string"] as? String, "text")
        XCTAssertEqual(unarchived["integer"] as? Int, 42)
        XCTAssertEqual(unarchived["float"] as? Double, 1.5)
        XCTAssertEqual(unarchived["boolean"] as? Bool, true)
        XCTAssertTrue(unarchived["nothing"] is NSNull)
        XCTAssertTrue(unarchived["date"] is Date)
        XCTAssertEqual((unarchived["date"] as? Date)?.timeIntervalSince1970 ?? .nan, 1008385183, accuracy: 0.0005)
        XCTAssertEqual(unarchived["binary"] as? Data, Data("hello".utf8))
        XCTAssertEqual(unarchived["sequence"] as? [String], ["a", "b"])
        XCTAssertEqual(unarchived["mapping"] as? [String: String], ["key": "value"])
        XCTAssertEqual(unarchived["set"] as? Set<String>, ["a", "b"])
    }

    func testAnchorReplacementHazard() {
        // This test verifies that initWithCoder: returning a different object
        // after an anchor has been resolved triggers an exception.
        // The YAML encodes a parent object with an anchor, which contains a child
        // that references the parent via alias (creating a cycle). The parent's
        // initWithCoder: returns a different object (simulating CALayer pattern).

        // Use !YACYAMLSwiftSelfReplacingObject tag to get our custom class
        let yaml = """
            parent: &anchor !YACYAMLSwiftSelfReplacingObject
              child: *anchor

            """  // Child references parent - creates cycle during decode

        // This should trigger the YACYAMLAnchorReplacementException because:
        // 1. Parent starts decoding, registers anchor "anchor"
        // 2. Child decodes, resolves anchor "anchor" -> parent's unarchiving object
        // 3. Parent's initWithCoder: runs, returns different object
        // 4. _anchorWasResolved is YES -> exception fires
        // (The error-returning method returns the exception that is raised, as an error.)
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml), "Should have caught the anchor replacement hazard") { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, CocoaError.coderReadCorrupt.rawValue)
            XCTAssertEqual((nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.code, YACYAMLError.unsupported.rawValue)
            XCTAssertTrue(nsError.localizedDescription.contains("different object"), nsError.localizedDescription)
        }
    }

    func testAnchorReplacementExceptionKeepsStackBalanced() {
        // After the replacement exception, the unarchiver's object stack must be
        // balanced again. The decoding happens in the unarchiver's initializer, so the
        // unarchiver is otherwise unreachable once the exception is thrown: it is
        // captured from inside initWithCoder:.
        let yaml = """
            parent: &anchor !YACYAMLSwiftCapturingReplacingObject
              child: *anchor

            """

        YACYAMLSwiftCapturedUnarchiver = nil
        // (The error-returning method returns the exception that is raised, as an error.)
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml), "Should have caught the anchor replacement hazard") { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, CocoaError.coderReadCorrupt.rawValue)
            XCTAssertEqual((nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.code, YACYAMLError.unsupported.rawValue)
            XCTAssertTrue(nsError.localizedDescription.contains("different object"), nsError.localizedDescription)
        }

        XCTAssertNotNil(YACYAMLSwiftCapturedUnarchiver, "initWithCoder: should have run")
        XCTAssertEqual(YACYAMLSwiftCapturedUnarchiver?.unarchivingObjectStackDepth(), 0,
                       "Unarchiving object stack should be balanced after exception")
        YACYAMLSwiftCapturedUnarchiver = nil
    }

    func testAnchorNoReplacementSafe() throws {
        // Same cycle structure, but initWithCoder: returns self (normal case).
        // Should NOT trigger assertion.
        let yaml = """
            parent: &anchor !YACYAMLSwiftNormalObject
              child: *anchor

            """

        let result = try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml)
        XCTAssertNotNil(result, "Should unarchive without assertion")
        let dict = result as! NSDictionary
        let parent = dict["parent"] as? NormalObject
        XCTAssertNotNil(parent, "Unexpected parent: \(String(describing: dict["parent"]))")
        XCTAssertTrue(parent?.child as AnyObject === parent, "Cycle should resolve to same object")
    }
}
