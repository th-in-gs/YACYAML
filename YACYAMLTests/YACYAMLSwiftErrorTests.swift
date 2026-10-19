//
//  YACYAMLSwiftErrorTests.swift
//  YACYAMLTests
//
//  Tests of the Swift-facing API: options as OptionSets, and the methods that throw.
//

import XCTest

/// Raises YACYAMLUnsupportedTypeException when encoded or decoded.
@objc(YACYAMLSwiftUnsupportedObject)
class UnsupportedObject: NSObject, NSCoding {
    override init() {
        super.init()
    }

    func encode(with coder: NSCoder) {
        var value: Int32 = 0
        coder.encodeValue(ofObjCType: "{unsupported=i}", at: &value)
    }

    required init?(coder: NSCoder) {
        var value: Int32 = 0
        coder.decodeValue(ofObjCType: "{unsupported=i}", at: &value)
        super.init()
    }
}

/// Fails its decode with its own error, as modern classes do.
@objc(YACYAMLSwiftFailingObject)
final class FailingObject: NSObject, NSCoding {
    override init() {
        super.init()
    }

    func encode(with coder: NSCoder) {
    }

    required init?(coder: NSCoder) {
        coder.failWithError(NSError(domain: "app.domain", code: 7, userInfo: [NSLocalizedDescriptionKey: "app says no"]))
        return nil
    }
}

class YACYAMLSwiftErrorTests: YACYAMLSwiftTestCase {
    /// The error underneath one of ours, which has the YACYAML-specific code.
    func underlyingYACYAMLError(_ error: Error, file: StaticString = #filePath, line: UInt = #line) -> NSError? {
        let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError
        XCTAssertEqual(underlying?.domain, YACYAMLErrorDomain, file: file, line: line)
        return underlying
    }

    func testOptionsAreOptionSets() {
        let options: YACYAMLKeyedArchiverOptions = [.allowScalarAnchors, .dontUseObjectEquality, .disallowLocalTags]
        XCTAssertTrue(options.contains(.allowScalarAnchors))
        XCTAssertTrue(options.contains(.dontUseObjectEquality))
        XCTAssertTrue(options.contains(.disallowLocalTags))
        XCTAssertEqual(options.rawValue, 0x0E)
        XCTAssertEqual(YACYAMLKeyedArchiverOptions([]).rawValue, 0)

        let unarchiverOptions: YACYAMLKeyedUnarchiverOptions = [.presentDocumentsAsArray, .disallowInitWithCoder, .disallowLocalTags]
        XCTAssertEqual(unarchiverOptions.rawValue, 0x07)
    }

    func testUnarchivingThrowsOnBadYAML() {
        // The errors are in the Cocoa domain, with the code that NSKeyedUnarchiver uses for data that
        // can't be read, and have the YACYAML error, with its code, underneath.
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: "- a\n- [b\n", options: [])) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, CocoaError.coderReadCorrupt.rawValue)
            XCTAssertNotNil(nsError.userInfo[YACYAMLErrorLineKey])
            XCTAssertNotNil(nsError.userInfo[YACYAMLErrorColumnKey])
            XCTAssertFalse(nsError.localizedDescription.isEmpty)
            XCTAssertEqual(nsError.userInfo[NSDebugDescriptionErrorKey] as? String, nsError.localizedDescription)
            XCTAssertEqual(underlyingYACYAMLError(error)?.code, YACYAMLError.parse.rawValue)
        }
    }

    func testUnarchivingErrorHasPosition() {
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: "a: 1\nb: [x\nc: 3\n", options: [])) { error in
            // This is where libyaml notices the problem, which can be later than the mistake (the
            // flow sequence on line 2 is not closed, but it's not noticed until line 3).
            let userInfo = (error as NSError).userInfo
            XCTAssertEqual(userInfo[YACYAMLErrorLineKey] as? Int, 3)
            XCTAssertEqual(userInfo[YACYAMLErrorColumnKey] as? Int, 2)
            let underlying = underlyingYACYAMLError(error)
            XCTAssertEqual(underlying?.userInfo[YACYAMLErrorLineKey] as? Int, 3)
        }
    }

    func testUnarchivingThrowsOnBadData() {
        let data = Data("{ unterminated".utf8)
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data, options: [])) { error in
            XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain)
            XCTAssertEqual((error as NSError).code, CocoaError.coderReadCorrupt.rawValue)
        }
    }

    func testUnarchivingThrowsOnEmptyInput() {
        // As NSKeyedUnarchiver does for empty data.
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: "", options: [])) { error in
            XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain)
            XCTAssertEqual((error as NSError).code, CocoaError.coderReadCorrupt.rawValue)
            XCTAssertEqual(underlyingYACYAMLError(error)?.code, YACYAMLError.parse.rawValue)
        }
    }

    func testUnarchivingGoodYAMLDoesNotThrow() throws {
        let object = try YACYAMLKeyedUnarchiver.unarchivedObject(from: "- 1\n- two\n", options: [])
        assertEqualObjects(object, [1, "two"], "Unexpected result")
    }

    func testUnarchivingMissingFileThrowsFileError() {
        // The same error that NSData gives for a file that isn't there, with the POSIX error underneath.
        let path = NSTemporaryDirectory() + "YACYAMLSwiftErrorTests-does-not-exist.yaml"
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(fromFile: path, options: [])) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, CocoaError.fileReadNoSuchFile.rawValue)
            XCTAssertEqual(nsError.userInfo[NSFilePathErrorKey] as? String, path)
            let posix = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
            XCTAssertEqual(posix?.domain, NSPOSIXErrorDomain)
            XCTAssertEqual(posix?.code, Int(ENOENT))
        }
    }

    func testFileRoundTripWithErrors() throws {
        let path = NSTemporaryDirectory() + "YACYAMLSwiftErrorTests-\(UUID().uuidString).yaml"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let original: [String: Any] = ["a": 1, "b": ["x", "y"]]
        try YACYAMLKeyedArchiver.archiveRootObject(original, toFile: path, options: [])
        let read = try YACYAMLKeyedUnarchiver.unarchivedObject(fromFile: path, options: [])
        assertEqualObjects(read, original, "File round trip failed")
    }

    func testArchivingToUnwritableFileThrowsFileError() {
        let path = NSTemporaryDirectory() + "YACYAMLSwiftErrorTests-no-such-directory/file.yaml"
        XCTAssertThrowsError(try YACYAMLKeyedArchiver.archiveRootObject(["a"], toFile: path, options: [])) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, CocoaError.fileNoSuchFile.rawValue)
            XCTAssertEqual((nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.domain, NSPOSIXErrorDomain)
        }
    }

    func testArchivingUnsupportedObjectThrows() {
        XCTAssertThrowsError(try YACYAMLKeyedArchiver.archivedData(withRootObject: [UnsupportedObject()], options: [])) { error in
            // The code that NSKeyedArchiver uses for something that can't be written.
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, CocoaError.coderInvalidValue.rawValue)
            XCTAssertEqual(underlyingYACYAMLError(error)?.code, YACYAMLError.unsupported.rawValue)
        }
        XCTAssertThrowsError(try YACYAMLKeyedArchiver.archivedString(withRootObject: UnsupportedObject(), options: []))
    }

    func testUnarchivingUnsupportedObjectThrows() {
        // It's valid YAML, but the object can't be decoded.  The error says where the object that
        // was being decoded starts, as well as what was wrong.
        let yaml = "- first\n- second\n- !YACYAMLSwiftUnsupportedObject {}\n"
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml, options: [])) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, CocoaError.coderReadCorrupt.rawValue)
            XCTAssertEqual(nsError.userInfo[YACYAMLErrorLineKey] as? Int, 3)
            XCTAssertTrue(nsError.localizedDescription.contains("line 3"), nsError.localizedDescription)
            XCTAssertEqual(underlyingYACYAMLError(error)?.code, YACYAMLError.unsupported.rawValue)
        }
    }

    func testClassesFailingWithTheirOwnErrorsReturnThemUnchanged() {
        // As NSKeyedUnarchiver does, an error from a class's own -failWithError: is what's returned.
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: "- !YACYAMLSwiftFailingObject {}\n", options: [])) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "app.domain")
            XCTAssertEqual(nsError.code, 7)
            XCTAssertEqual(nsError.localizedDescription, "app says no")
        }
    }

    func testUnsupportedCoderMethodsRaise() throws {
        // Methods of NSCoder that are historical, or that don't fit with YAML, raise a clear
        // exception rather than doing something odd.  (Swift can't catch it, so it's caught by
        // the Objective-C that the tests use.)
        let archiver: YACYAMLKeyedArchiver = YACYAMLKeyedArchiver(forWritingWith: NSMutableData())
        let unarchiver = try YACYAMLKeyedUnarchiver(forReadingFrom: Data("value\n".utf8))

        // These are allocated, and passed as they are, not as inout arguments (&value): Swift keeps track
        // of inout accesses, and an Objective-C exception that unwinds through one leaves it
        // recorded, which crashes the next time the variable is used.
        let value = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        let length = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        let byte = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer {
            value.deallocate()
            length.deallocate()
            byte.deallocate()
        }

        var calls: [(String, () -> Void)] = [
            ("encodeBytes:length:", { archiver.encodeBytes(byte, length: 1) }),
            ("encodeArrayOfObjCType:count:at:", { archiver.encodeArray(ofObjCType: "i", count: 1, at: value) }),
            ("versionForClassName:", { _ = archiver.version(forClassName: "NSString") }),
            ("decodePropertyListForKey:", { _ = unarchiver.decodePropertyList(forKey: "k") }),
            ("decodeBytesWithReturnedLength:", { _ = unarchiver.decodeBytes(withReturnedLength: length) }),
            ("decodeArrayOfObjCType:count:at:", { unarchiver.decodeArray(ofObjCType: "i", count: 1, at: value) }),
            ("versionForClassName:", { _ = unarchiver.version(forClassName: "NSString") }),
        ]
        #if os(macOS)
        // (The iOS SDK doesn't have these in Swift.  The Objective-C tests cover them there.)
        calls.append(("encodePropertyList:", { archiver.encodePropertyList("x") }))
        calls.append(("decodePropertyList", { _ = unarchiver.decodePropertyList() }))
        #endif
        for (name, call) in calls {
            let exception = YACYAMLSwiftCatchException(call)
            XCTAssertEqual(exception?.name, .yacyamlUnsupportedMethod, name)
            XCTAssertTrue(exception?.reason?.contains(name) ?? false, "\(String(describing: exception?.reason)) should name \(name)")
        }
    }

    func testSystemVersion() throws {
        // There's no system version in YAML archives, so this is what NSCoder says, from both.
        let archiver: YACYAMLKeyedArchiver = YACYAMLKeyedArchiver(forWritingWith: NSMutableData())
        let unarchiver = try YACYAMLKeyedUnarchiver(forReadingFrom: Data("value\n".utf8))
        XCTAssertNil(YACYAMLSwiftCatchException { _ = archiver.systemVersion })
        XCTAssertNil(YACYAMLSwiftCatchException { _ = unarchiver.systemVersion })
        XCTAssertEqual(archiver.systemVersion, unarchiver.systemVersion)
    }

    func testThrowingFormsWithoutOptions() throws {
        // The usual calls, with no options, as for NSKeyedArchiver and NSKeyedUnarchiver.
        let value: [String: Any] = ["a": 1, "b": ["x", "y"]]
        let string: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: value)
        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: value)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)

        assertEqualObjects(try YACYAMLKeyedUnarchiver.unarchivedObject(from: string), value)
        assertEqualObjects(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data), value)

        let path = NSTemporaryDirectory() + "YACYAMLSwiftErrorTests-\(UUID().uuidString).yaml"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try YACYAMLKeyedArchiver.archiveRootObject(value, toFile: path)
        assertEqualObjects(try YACYAMLKeyedUnarchiver.unarchivedObject(fromFile: path), value)

        // The initializers throw, and NSKeyedUnarchiver's label for reading from data works.
        let unarchiver = try YACYAMLKeyedUnarchiver(forReadingFrom: data)
        assertEqualObjects(unarchiver.decodeObject(), value)
        XCTAssertNoThrow(try YACYAMLKeyedUnarchiver(forReadingWithFile: path))
        XCTAssertNoThrow(try YACYAMLKeyedArchiver(forWritingToFile: path))

        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: "[unterminated"))
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver(forReadingFrom: Data("[unterminated".utf8)))
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver(forReadingWithFile: "/nonexistent/file.yaml"))
        XCTAssertThrowsError(try YACYAMLKeyedArchiver(forWritingToFile: "/nonexistent/file.yaml"))
        XCTAssertThrowsError(try YACYAMLKeyedArchiver.archivedString(withRootObject: UnsupportedObject()))
    }

    func testUnarchivedObjectOfClass() throws {
        // As for NSKeyedUnarchiver, the decoded object has to be of the class (or a subclass).
        let data = Data("- a\n- b\n".utf8)
        let array = try YACYAMLKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: data)
        assertEqualObjects(array, ["a", "b"])
        XCTAssertNotNil(try YACYAMLKeyedUnarchiver.unarchivedObject(ofClass: NSObject.self, from: data))
        XCTAssertNotNil(try YACYAMLKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: data, options: [.disallowLocalTags]))

        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: data)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, CocoaError.coderReadCorrupt.rawValue)
            XCTAssertTrue(nsError.localizedDescription.contains("NSDictionary"), nsError.localizedDescription)
        }

        // Bad YAML is still reported as it always is.
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: Data("[x".utf8))) { error in
            XCTAssertEqual(underlyingYACYAMLError(error)?.code, YACYAMLError.parse.rawValue)
        }
    }

    func testArchivingWithErrorsMatchesArchivingWithout() throws {
        let value: [String: Any] = ["numbers": [1, 2.5, true], "text": "hello", "nothing": NSNull()]
        let plain = try YACYAMLKeyedArchiver.archivedString(withRootObject: value)
        let checked = try YACYAMLKeyedArchiver.archivedString(withRootObject: value, options: [])
        XCTAssertEqual(plain, checked)
    }

    func testFinishEncodingThrowing() throws {
        let data = NSMutableData()
        let archiver = YACYAMLKeyedArchiver(forWritingWith: data)
        archiver.encodeRootObject(["a", "b"])
        try archiver.finishEncoding()
        XCTAssertEqual(String(data: data as Data, encoding: .utf8), "- a\n- b\n")
    }

    func testInitializersThrow() {
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver(forReadingWith: Data("[".utf8), options: []))
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver(forReadingWithFile: "/nonexistent/file.yaml", options: []))
        XCTAssertThrowsError(try YACYAMLKeyedArchiver(forWritingToFile: "/nonexistent/file.yaml", options: []))
    }

    func testObjectExtensionsThrow() throws {
        // The extensions are on the Objective-C classes, so Swift's native types must be bridged to see them.
        let encoded = try ([1, 2, 3] as NSArray).yacyamlEncodedString()
        XCTAssertEqual(encoded, "- 1\n- 2\n- 3\n")
        let decoded = try (encoded as NSString).yacyamlDecodeBasic()
        assertEqualObjects(decoded, [1, 2, 3], "Round trip failed")
        XCTAssertThrowsError(try ("[" as NSString).yacyamlDecodeAll())
        XCTAssertThrowsError(try (Data("[".utf8) as NSData).yacyamlDecodeBasic())
        XCTAssertThrowsError(try UnsupportedObject().yacyamlEncodedData())
    }
}
