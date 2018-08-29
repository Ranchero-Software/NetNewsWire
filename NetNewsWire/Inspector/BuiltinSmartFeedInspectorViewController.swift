//
//  BuiltinSmartFeedInspectorViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

final class BuiltinSmartFeedInspectorViewController: NSViewController, Inspector {

	@IBOutlet var nameTextField: NSTextField?

	private var smartFeed: PseudoFeed? {
		didSet {
			updateUI()
		}
	}

	// MARK: Inspector

	let isFallbackInspector = false
	var objects: [Any]? {
		didSet {
			updateSmartFeed()
		}
	}

	func canInspect(_ objects: [Any]) -> Bool {

		guard let _ = singleSmartFeed(from: objects) else {
			return false
		}
		return true
	}

	// MARK: NSViewController

	override func viewDidLoad() {

		updateUI()
	}
}

private extension BuiltinSmartFeedInspectorViewController {

	func singleSmartFeed(from objects: [Any]?) -> PseudoFeed? {

		guard let objects = objects, objects.count == 1, let singleSmartFeed = objects.first as? PseudoFeed else {
			return nil
		}

		return singleSmartFeed
	}

	func updateSmartFeed() {

		smartFeed = singleSmartFeed(from: objects)
	}

	func updateUI() {

		nameTextField?.stringValue = smartFeed?.nameForDisplay ?? ""
	}
}
