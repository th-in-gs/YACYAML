//
//  YACYAMLSwiftViewTests.swift
//  YACYAMLTests
//
//  Swift ports of the view, button and layer tests in YACYAMLTests.m.
//

import XCTest
import QuartzCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

final class YACYAMLSwiftViewTests: YACYAMLSwiftTestCase {
#if os(iOS)
    func testUIView() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.backgroundColor = .red

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: view)

        XCTAssertTrue(data.count != 0, "Archived data unexpectedly zero length")

        let unarchivedView: UIView = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as! UIView

        XCTAssertEqual(try YACYAMLKeyedArchiver.archivedData(withRootObject: unarchivedView), data, "Unarchived object not equal to archived object")
    }

    func testUIButton() throws {
        let button = UIButton(type: .custom)
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        button.backgroundColor = .red
        button.setTitle("Tap Me", for: .normal)

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: button)

        XCTAssertTrue(data.count != 0, "Archived data unexpectedly zero length")

        let unarchivedView: UIView = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as! UIView

        XCTAssertEqual(try YACYAMLKeyedArchiver.archivedData(withRootObject: unarchivedView), data, "Unarchived object not equal to archived object")
    }
#endif

#if os(macOS)
    func testNSView() throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 480))
        view.autoresizingMask = [.width, .height]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: view)

        XCTAssertTrue(data.count != 0, "Archived data unexpectedly zero length")

        let unarchivedView: NSView = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as! NSView

        XCTAssertEqual(try YACYAMLKeyedArchiver.archivedData(withRootObject: unarchivedView), data, "Unarchived object not equal to archived object")
    }

    func testNSButton() throws {
        let button = NSButton(title: "Tap Me", target: nil, action: nil)
        button.autoresizingMask = [.width, .height]

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: button)

        XCTAssertTrue(data.count != 0, "Archived data unexpectedly zero length")

        let unarchivedView: NSView = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as! NSView

        XCTAssertEqual(try YACYAMLKeyedArchiver.archivedData(withRootObject: unarchivedView), data, "Unarchived object not equal to archived object")
    }
#endif

    func testCALayer() throws {
        let layer = CALayer()
        layer.name = "layer"
        layer.bounds = CGRect(x: 0, y: 0, width: 320, height: 480)
        layer.position = CGPoint(x: 10, y: 20)
        layer.opacity = 0.5
        layer.cornerRadius = 8

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: layer)

        XCTAssertTrue(data.count != 0, "Archived data unexpectedly zero length")

        let unarchivedLayer = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as? CALayer

        XCTAssertNotNil(unarchivedLayer, "Got \(String(describing: unarchivedLayer))")
        guard let unarchivedLayer = unarchivedLayer else { return }
        XCTAssertEqual(unarchivedLayer.name, "layer")
        XCTAssertEqual(unarchivedLayer.bounds, CGRect(x: 0, y: 0, width: 320, height: 480))
        XCTAssertEqual(unarchivedLayer.position, CGPoint(x: 10, y: 20))
        XCTAssertEqual(unarchivedLayer.opacity, 0.5)
        XCTAssertEqual(unarchivedLayer.cornerRadius, 8)
        XCTAssertEqual(try YACYAMLKeyedArchiver.archivedData(withRootObject: unarchivedLayer), data, "Unarchived object not equal to archived object")
    }

    func testCALayerHierarchy() throws {
        let parent = CALayer()
        parent.name = "parent"
        for i in 0..<3 {
            let child = CALayer()
            child.name = "child \(i)"
            child.bounds = CGRect(x: 0, y: 0, width: 10 * (i + 1), height: 10)
            parent.addSublayer(child)
        }

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: parent)
        let unarchivedParent = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as! CALayer

        XCTAssertEqual(unarchivedParent.name, "parent")
        XCTAssertEqual(unarchivedParent.sublayers?.count, 3)
        for (i, child) in (unarchivedParent.sublayers ?? []).enumerated() {
            XCTAssertEqual(child.name, "child \(i)")
            XCTAssertEqual(child.bounds.size.width, CGFloat(10 * (i + 1)))
            XCTAssertTrue(child.superlayer === unarchivedParent, "Sublayers should be attached to the unarchived parent")
        }
        XCTAssertEqual(try YACYAMLKeyedArchiver.archivedData(withRootObject: unarchivedParent), data, "Unarchived object not equal to archived object")
    }

    func testCALayerSharedReference() throws {
        // The second occurrence is archived as an alias of the first.
        let layer = CALayer()
        layer.name = "shared"
        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedData(withRootObject: [layer, layer])) as! [CALayer]

        XCTAssertEqual(unarchived.count, 2)
        XCTAssertTrue(unarchived[0] === unarchived[1], "Both references should be the same object")
        XCTAssertEqual(unarchived[0].name, "shared")
    }

    // The replacing layer is Objective-C (see YACYAMLSwiftTestSupport.h): Swift initializers can't return a different object.
    func testReplacingLayer() throws {
        let layer = YACYAMLSwiftReplacingLayer()
        layer.name = "replaced"
        layer.bounds = CGRect(x: 0, y: 0, width: 30, height: 40)

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: layer)
        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: data) as? YACYAMLSwiftReplacingLayer

        XCTAssertNotNil(unarchived, "Got \(String(describing: unarchived))")
        XCTAssertEqual(unarchived?.name, "replaced")
        XCTAssertEqual(unarchived?.bounds, CGRect(x: 0, y: 0, width: 30, height: 40))
    }

    func testReplacingLayerAsSublayer() throws {
        // The replacement must end up in the hierarchy, not the discarded original.
        let parent = CALayer()
        for i in 0..<3 {
            let child = YACYAMLSwiftReplacingLayer()
            child.name = "child \(i)"
            parent.addSublayer(child)
        }

        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedData(withRootObject: parent)) as! CALayer

        XCTAssertEqual(unarchived.sublayers?.count, 3)
        for (i, child) in (unarchived.sublayers ?? []).enumerated() {
            XCTAssertTrue(child is YACYAMLSwiftReplacingLayer)
            XCTAssertEqual(child.name, "child \(i)")
            XCTAssertTrue(child.superlayer === unarchived)
        }
    }

    func testReplacingLayerAliasedAfterReplacement() throws {
        // Later references to a replaced object resolve to the replacement, not the discarded original.
        let layer = YACYAMLSwiftReplacingLayer()
        layer.name = "shared"
        let root: [String: Any] = ["first": layer, "second": layer, "third": [layer]]

        let unarchived = try YACYAMLKeyedUnarchiver.unarchivedObject(from: try YACYAMLKeyedArchiver.archivedData(withRootObject: root)) as! [String: Any]

        let first = unarchived["first"] as? YACYAMLSwiftReplacingLayer
        XCTAssertNotNil(first, "Got \(String(describing: first))")
        XCTAssertEqual(first?.name, "shared")
        XCTAssertTrue((unarchived["second"] as AnyObject) === first, "Aliases should resolve to the replacement object")
        XCTAssertTrue(((unarchived["third"] as? [AnyObject])?.first) === first, "Aliases should resolve to the replacement object")
    }

    func testReplacingLayerCycleIsRejected() throws {
        // Each layer refers to the other. While one is being decoded, the other resolves its
        // anchor, and would be left holding the discarded original: this is detected.
        let a = YACYAMLSwiftReplacingLayer()
        let b = YACYAMLSwiftReplacingLayer()
        a.partner = b
        b.partner = a

        let data: Data = try YACYAMLKeyedArchiver.archivedData(withRootObject: a)
        // (The error-returning method returns the exception that is raised, as an error.)
        XCTAssertThrowsError(try YACYAMLKeyedUnarchiver.unarchivedObject(from: data), "Should have caught the anchor replacement hazard") { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, CocoaError.coderReadCorrupt.rawValue)
            XCTAssertEqual((nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.code, YACYAMLError.unsupported.rawValue)
            XCTAssertTrue(nsError.localizedDescription.contains("different object"), nsError.localizedDescription)
        }
    }
}
