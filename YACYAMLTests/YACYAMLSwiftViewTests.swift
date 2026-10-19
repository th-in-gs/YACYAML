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

    #if os(macOS)
    func testNSViewSuperviewIsConditional() throws {
        // A view encodes its superview conditionally, so archiving a view doesn't also archive its superview,
        // or that view's other subviews, but archiving the superview does bring its subviews, and they
        // still have it as their superview.
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let child = NSView(frame: NSRect(x: 1, y: 2, width: 10, height: 10))
        let sibling = NSView(frame: NSRect(x: 5, y: 5, width: 10, height: 10))
        parent.identifier = NSUserInterfaceItemIdentifier("the-parent")
        child.identifier = NSUserInterfaceItemIdentifier("the-child")
        sibling.identifier = NSUserInterfaceItemIdentifier("the-sibling")
        parent.addSubview(child)
        parent.addSubview(sibling)

        var archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: child)
        XCTAssertTrue(archived.contains("the-child"), archived)
        XCTAssertFalse(archived.contains("the-parent"), "The superview was archived:\n\(archived)")
        XCTAssertFalse(archived.contains("the-sibling"), "A sibling was archived:\n\(archived)")
        let decodedChild = try XCTUnwrap(YACYAMLKeyedUnarchiver.unarchivedObject(from: archived) as? NSView)
        XCTAssertEqual(decodedChild.identifier?.rawValue, "the-child")
        XCTAssertNil(decodedChild.superview)

        archived = try YACYAMLKeyedArchiver.archivedString(withRootObject: parent)
        let decodedParent = try XCTUnwrap(YACYAMLKeyedUnarchiver.unarchivedObject(from: archived) as? NSView)
        XCTAssertEqual(decodedParent.identifier?.rawValue, "the-parent")
        XCTAssertEqual(decodedParent.subviews.map { $0.identifier?.rawValue }, ["the-child", "the-sibling"])
        XCTAssertTrue(decodedParent.subviews.allSatisfy { $0.superview === decodedParent })
        XCTAssertEqual(try YACYAMLKeyedArchiver.archivedString(withRootObject: decodedParent), archived)
    }
    #endif

    #if os(iOS)
    func testUIViewSuperviewIsConditional() throws {
        // See testNSViewSuperviewIsConditional.  UIKit's views don't encode their superview (it's set when
        // their superview decodes its subviews), so this doesn't use conditional encoding, but it checks
        // that views are still archived on their own, and with their subviews.  (UIView archives its tag,
        // so that's used to tell the views apart.)
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let child = UIView(frame: CGRect(x: 1, y: 2, width: 10, height: 10))
        let sibling = UIView(frame: CGRect(x: 5, y: 5, width: 10, height: 10))
        parent.tag = 50211
        child.tag = 50212
        sibling.tag = 50213
        parent.addSubview(child)
        parent.addSubview(sibling)

        var archived: String = try YACYAMLKeyedArchiver.archivedString(withRootObject: child)
        XCTAssertTrue(archived.contains("50212"), archived)
        XCTAssertFalse(archived.contains("50211"), "The superview was archived:\n\(archived)")
        XCTAssertFalse(archived.contains("50213"), "A sibling was archived:\n\(archived)")
        let decodedChild = try XCTUnwrap(YACYAMLKeyedUnarchiver.unarchivedObject(from: archived) as? UIView)
        XCTAssertEqual(decodedChild.tag, 50212)
        XCTAssertNil(decodedChild.superview)

        archived = try YACYAMLKeyedArchiver.archivedString(withRootObject: parent)
        let decodedParent = try XCTUnwrap(YACYAMLKeyedUnarchiver.unarchivedObject(from: archived) as? UIView)
        XCTAssertEqual(decodedParent.tag, 50211)
        XCTAssertEqual(decodedParent.subviews.map { $0.tag }, [50212, 50213])
        XCTAssertTrue(decodedParent.subviews.allSatisfy { $0.superview === decodedParent })
        XCTAssertEqual(try YACYAMLKeyedArchiver.archivedString(withRootObject: decodedParent), archived)
    }
    #endif
}
