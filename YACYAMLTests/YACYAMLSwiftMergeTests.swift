//
//  YACYAMLSwiftMergeTests.swift
//  YACYAMLTests
//
//  Swift ports of the merge key and decoding extension tests in YACYAMLTests.m.
//

import XCTest

final class YACYAMLSwiftMergeTests: YACYAMLSwiftTestCase {
    func testMergeParsing() throws {
        let yaml = """
            ---
            - &CENTER { x: 1, y: 2 }
            - &LEFT { x: 0, y: 2 }
            - &BIG { r: 10 }
            - &SMALL { r: 1 }

            # All the following maps are equal:

            - # Explicit keys
              x: 1
              y: 2
              r: 10
              label: center/big

            - # Merge one map
              << : *CENTER
              r: 10
              label: center/big

            - # Merge multiple maps
              << : [ *CENTER, *BIG ]
              label: center/big

            - # Override
              << : [ *BIG, *LEFT, *SMALL ]
              x: 1
              label: center/big

            """

        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: yaml) as? [Any]

        XCTAssertTrue(unarchived?.isEmpty == false, "Unexpected count after merge parsing")
    }

    func testMergingFromCustomTypes() throws {
        let yaml = """
            ---
            original: !YACYAMLSwiftCustomTypeMerging &CUSTOMTYPEMERGE
                key1: this key should be inherited
                key2: this key should be overridden
            # Keys can be merged from custom types into other custom types
            mergedCustomType: !YACYAMLSwiftCustomTypeMerging
                <<: *CUSTOMTYPEMERGE
                key2: override for key2
            # Keys can be merged from custom types into regular maps
            mergedMap:
                <<: *CUSTOMTYPEMERGE
                key2: override for key2

            """

        let unarchived = unarchivedDictionary(yaml) as! [String: Any]
        XCTAssertEqual(unarchived.count, 3)

        let original = unarchived["original"] as? CustomTypeMerging
        XCTAssertNotNil(original)
        XCTAssertEqual(original?.property1, "this key should be inherited")
        XCTAssertEqual(original?.property2, "this key should be overridden")

        let mergedCustomType = unarchived["mergedCustomType"] as? CustomTypeMerging
        XCTAssertNotNil(mergedCustomType)
        XCTAssertEqual(mergedCustomType?.property1, "this key should be inherited")
        XCTAssertEqual(mergedCustomType?.property2, "override for key2")

        let mergedMap = unarchived["mergedMap"] as? [String: Any]
        XCTAssertNotNil(mergedMap)
        XCTAssertEqual(mergedMap?["key1"] as? String, "this key should be inherited")
        XCTAssertEqual(mergedMap?["key2"] as? String, "override for key2")
    }

    func testYAMLExtensions() throws {
        let yaml = """
            empty:
            canonical: ~
            english: null
            ~: null key

            """

        func check(_ decoded: Any?, _ description: String) throws {
            let dictionary = decoded as? [AnyHashable: Any]
            XCTAssertNotNil(dictionary, "\(description): expected a mapping, got \(String(describing: decoded))")
            XCTAssertEqual(dictionary?["empty"] as? NSNull, NSNull(), "\(description): Unexpected result after unarchiving")
            XCTAssertEqual(dictionary?["canonical"] as? NSNull, NSNull(), "\(description): Unexpected result after unarchiving")
            XCTAssertEqual(dictionary?["english"] as? NSNull, NSNull(), "\(description): Unexpected result after unarchiving")
            XCTAssertEqual(dictionary?[NSNull()] as? String, "null key", "\(description): Unexpected result after unarchiving")
        }

        try check(try yaml.yacyamlDecode(), "yacyamlDecode")
        try check(try yaml.yacyamlDecodeBasic(), "yacyamlDecodeBasic")
        try check(try yaml.yacyamlDecodeAll(), "yacyamlDecodeAll")
    }
}
