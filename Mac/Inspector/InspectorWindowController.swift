//
//  InspectorWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

protocol Inspector: AnyObject {

	var objects: [Any]? { get set }
	var isFallbackInspector: Bool { get } // Can handle nothing-to-inspect or unexpected type of objects.
	var windowTitle: String { get }

	func canInspect(_ objects: [Any]) -> Bool
}

typealias InspectorViewController = Inspector & NSViewController


final class InspectorWindowController: NSWindowController {

	class var shouldOpenAtStartup: Bool {
		return UserDefaults.standard.bool(forKey: DefaultsKey.windowIsOpen)
	}

	var objects: [Any]? {
		didSet {
			let _ = window
			currentInspector = inspector(for: objects)
		}
	}

	private var inspectors: [InspectorViewController]!

	private var currentInspector: InspectorViewController! {
		didSet {
			currentInspector.objects = objects
			for inspector in inspectors {
				if inspector !== currentInspector {
					inspector.objects = nil
				}
			}
			show(currentInspector)
		}
	}

	private struct DefaultsKey {
		static let windowIsOpen = "FloatingInspectorIsOpen"
		static let windowOrigin = "FloatingInspectorOrigin"
	}

	override func windowDidLoad() {

		let nothingInspector = window?.contentViewController as! InspectorViewController

		let storyboard = NSStoryboard(name: NSStoryboard.Name("Inspector"), bundle: nil)
		let feedInspector = inspector("Feed", storyboard)
		let folderInspector = inspector("Folder", storyboard)
		let builtinSmartFeedInspector = inspector("BuiltinSmartFeed", storyboard)

		inspectors = [feedInspector, folderInspector, builtinSmartFeedInspector, nothingInspector]
		currentInspector = nothingInspector
		window?.title = currentInspector.windowTitle

		if let savedOrigin = originFromDefaults() {
			window?.setFlippedOriginAdjustingForScreen(savedOrigin)
		}
		else {
			window?.flippedOrigin = NSPoint(x: 256, y: 256)
		}
	}

	func inspector(for objects: [Any]?) -> InspectorViewController {

		var fallbackInspector: InspectorViewController? = nil

		for inspector in inspectors {
			if inspector.isFallbackInspector {
				fallbackInspector = inspector
			}
			else if let objects = objects, inspector.canInspect(objects) {
				return inspector
			}
		}

		return fallbackInspector!
	}

	func saveState() {

		UserDefaults.standard.set(isOpen, forKey: DefaultsKey.windowIsOpen)
		if isOpen, let window = window, let flippedOrigin = window.flippedOrigin {
			UserDefaults.standard.set(NSStringFromPoint(flippedOrigin), forKey: DefaultsKey.windowOrigin)
		}
	}
}

private extension InspectorWindowController {

	func inspector(_ identifier: String, _ storyboard: NSStoryboard) -> InspectorViewController {

		return storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as! InspectorViewController
	}

	func show(_ inspector: InspectorViewController) {

		guard let window = window else {
			return
		}

		DispatchQueue.main.async {
			window.title = inspector.windowTitle
		}	

		let flippedOrigin = window.flippedOrigin

		if window.contentViewController != inspector {
			window.contentViewController = inspector
			window.makeFirstResponder(nil)
		}
		
		window.layoutIfNeeded()
		if let flippedOrigin = flippedOrigin {
			window.setFlippedOriginAdjustingForScreen(flippedOrigin)
		}
	}

	func originFromDefaults() -> NSPoint? {

		guard let originString = UserDefaults.standard.string(forKey: DefaultsKey.windowOrigin) else {
			return nil
		}
		let point = NSPointFromString(originString)
		return point == NSPoint.zero ? nil : point
	}
}
