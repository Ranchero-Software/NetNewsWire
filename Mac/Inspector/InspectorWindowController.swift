//
//  InspectorWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

@MainActor protocol Inspector: AnyObject {
	var objects: [Any]? { get set }
	var windowTitle: String { get }

	func canInspect(_ objects: [Any]) -> Bool
}

typealias InspectorViewController = Inspector & NSViewController

final class InspectorWindowController: NSWindowController {
	static var shouldOpenAtStartup: Bool {
		return UserDefaults.standard.bool(forKey: DefaultsKey.windowIsOpen)
	}

	var objects: [Any]? {
		didSet {
			_ = window
			showInspector(for: objects)
		}
	}

	/// Handles nothing to inspect, multiple objects, and objects no other inspector can inspect.
	private let nothingInspector = NothingInspectorViewController()
	private let specificInspectors: [InspectorViewController] = [FeedInspectorViewController(), FolderInspectorViewController(), BuiltinSmartFeedInspectorViewController()]

	private struct DefaultsKey {
		static let windowIsOpen = "FloatingInspectorIsOpen"
		static let windowOrigin = "FloatingInspectorOrigin"
	}

	convenience init() {
		self.init(windowNibName: "InspectorWindow")
	}

	override func windowDidLoad() {

		showInspector(for: objects)
		window?.title = nothingInspector.windowTitle

		if let savedOrigin = originFromDefaults() {
			window?.setFlippedOriginAdjustingForScreen(savedOrigin)
		} else {
			window?.flippedOrigin = NSPoint(x: 256, y: 256)
		}
	}

	func inspector(for objects: [Any]?) -> InspectorViewController {
		guard let objects else {
			return nothingInspector
		}
		return specificInspectors.first { $0.canInspect(objects) } ?? nothingInspector
	}

	func saveState() {

		UserDefaults.standard.set(isOpen, forKey: DefaultsKey.windowIsOpen)
		if isOpen, let window = window, let flippedOrigin = window.flippedOrigin {
			UserDefaults.standard.set(NSStringFromPoint(flippedOrigin), forKey: DefaultsKey.windowOrigin)
		}
	}
}

private extension InspectorWindowController {

	func showInspector(for objects: [Any]?) {
		let currentInspector = inspector(for: objects)
		currentInspector.objects = objects
		for inspector in specificInspectors + [nothingInspector] where inspector !== currentInspector {
			inspector.objects = nil
		}
		show(currentInspector)
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
