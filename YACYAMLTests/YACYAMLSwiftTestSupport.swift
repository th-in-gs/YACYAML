//
//  YACYAMLSwiftTestSupport.swift
//  YACYAMLTests
//
//  Helpers shared by the Swift tests, and the test objects that Swift can implement.  (The
//  ones that replace themselves in -initWithCoder: can't be, as Swift initializers can't
//  return a different object; see YACYAMLSwiftTestSupport.h.)
//

import XCTest
import QuartzCore

/// The base of the Swift test cases.
///
/// The tests use native Swift types (String, Array, Dictionary, Set, Date, Data, Int, Double, Bool)
/// wherever they can, and the library's results are bridged to them.  Foundation reference types
/// (NSNumber, NSDecimalNumber, NSNull, CFBoolean) only appear where a test is about exactly them,
/// for example the C type a number was read back as.
class YACYAMLSwiftTestCase: XCTestCase {
    /// Checks that two values are equal as Objective-C objects (-isEqual:), which is how the
    /// Objective-C tests compare them.  It's for values that have no Swift type to compare as, such
    /// as arrays of mixed numbers, strings and NSNull.  (Note that NSNumber's -isEqual: is loose:
    /// 1, 1.0 and true are all equal.)
    func assertEqualObjects(_ actual: Any?, _ expected: Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
        let equal = (actual as? NSObject)?.isEqual(expected as? NSObject) ?? (actual == nil && expected == nil)
        XCTAssertTrue(equal, "\(String(describing: actual)) is not equal to \(String(describing: expected)) \(message())", file: file, line: line)
    }

    /// Unarchives a one-element sequence "- <scalar>\n", and returns its element.
    /// (These helpers fail the test if the YAML can't be read, rather than throwing, as they are used
    /// throughout expressions.)
    func unarchivedScalar(_ scalar: String, file: StaticString = #filePath, line: UInt = #line) -> Any? {
        var unarchived: [Any]?
        do {
            unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: "- \(scalar)\n") as? [Any]
        } catch {
            XCTFail("Unable to unarchive \(scalar): \(error)", file: file, line: line)
        }
        XCTAssertEqual(unarchived?.count, 1, "Unexpected result for \(scalar): \(String(describing: unarchived))")
        return unarchived?.first
    }

    /// Unarchives YAML that is a mapping.
    func unarchivedDictionary(_ yaml: String, file: StaticString = #filePath, line: UInt = #line) -> [AnyHashable: Any] {
        var unarchived: Any?
        do {
            unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml)
        } catch {
            XCTFail("Unable to unarchive \(yaml): \(error)", file: file, line: line)
        }
        XCTAssertTrue(unarchived is [AnyHashable: Any], "Expected a mapping, got \(String(describing: unarchived))")
        return (unarchived as? [AnyHashable: Any]) ?? [:]
    }

    /// Archives a one-element array containing the object, and extracts the scalar from "- <scalar>\n".
    func archivedScalar(for object: Any, file: StaticString = #filePath, line: UInt = #line) -> String {
        var archive = ""
        do {
            archive = try YACYAMLKeyedArchiver.archivedString(withRootObject: [object])
        } catch {
            XCTFail("Unable to archive \(object): \(error)", file: file, line: line)
        }
        guard let start = archive.range(of: "- ") else {
            XCTFail("Unexpected archive: \(archive)")
            return archive
        }
        return archive[start.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Has a custom type that can be merged into (see testMergingFromCustomTypes).
@objc(YACYAMLSwiftCustomTypeMerging)
final class CustomTypeMerging: NSObject, NSCoding {
    var property1: String?
    var property2: String?

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        property1 = coder.decodeObject(forKey: "key1") as? String
        property2 = coder.decodeObject(forKey: "key2") as? String
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(property1, forKey: "key1")
        coder.encode(property2, forKey: "key2")
    }
}

/// Encodes a nil, and checks that it decodes as one.
@objc(YACYAMLSwiftNilSubobjectObject)
final class NilSubobjectObject: NSObject, NSCoding {
    private var testSubobject: Any?

    override init() {
        super.init()
    }

    var decodedCorrectly: Bool {
        return testSubobject == nil
    }

    required init?(coder: NSCoder) {
        testSubobject = coder.decodeObject(forKey: "testSubobject")
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(nil, forKey: "testSubobject")
    }
}

/// An object whose -initWithCoder: returns self (the normal case).
@objc(YACYAMLSwiftNormalObject)
final class NormalObject: NSObject, NSCoding {
    var child: Any?

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        child = coder.decodeObject(forKey: "child")
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(child, forKey: "child")
    }
}

/// Provides its own YAML encoding, with a global tag.
@objc(YACYAMLSwiftGlobalTagObject)
final class GlobalTagObject: NSObject {
    @objc(YACYAMLArchivingTag) var archivingTag: String? { "tag:example.com,2026:global" }

    @objc(YACYAMLEncodeWithCoder:) func encodeYAML(with coder: YACYAMLKeyedArchiver) {
        coder.encode("global", forKey: "how")
    }
}

/// Provides its own YAML encoding, with a local tag.
@objc(YACYAMLSwiftLocalTagObject)
final class LocalTagObject: NSObject {
    @objc(YACYAMLArchivingTag) var archivingTag: String? { "!local" }

    @objc(YACYAMLEncodeWithCoder:) func encodeYAML(with coder: YACYAMLKeyedArchiver) {
        coder.encode("local", forKey: "how")
    }
}

/// Has some keyed bytes, that it decodes without asking for their length.
@objc(YACYAMLSwiftBytesObject)
final class BytesObject: NSObject, NSCoding {
    var decodedBytesWithNilLength = false
    var decodedMissingBytesAsNil = false
    var missingBytesLength = -1

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        let bytes = coder.decodeBytes(forKey: "bytes", returnedLength: nil)
        decodedBytesWithNilLength = bytes.map { memcmp($0, "abc", 3) == 0 } ?? false

        var length = 99
        let missing = coder.decodeBytes(forKey: "missing", returnedLength: &length)
        decodedMissingBytesAsNil = missing == nil && coder.decodeBytes(forKey: "missing", returnedLength: nil) == nil
        missingBytesLength = length
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encodeBytes([97, 98, 99], length: 3, forKey: "bytes")
    }
}

