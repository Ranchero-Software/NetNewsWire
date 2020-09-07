//
//  NothingInspectorViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

final class NothingInspectorViewController: NSViewController, Inspector {

	@IBOutlet var nothingTextField: NSTextField?
	@IBOutlet var multipleTextField: NSTextField?

	let isFallbackInspector = true
	var objects: [Any]? {
		didSet {
			updateTextFields()
		}
	}
	var windowTitle: String = NSLocalizedString("Inspector", comment: "Inspector window title")

	func canInspect(_ objects: [Any]) -> Bool {

		return true
	}

	override func viewDidLoad() {

		updateTextFields()
	}
}

private extension NothingInspectorViewController {

	func updateTextFields() {

		if let objects = objects, objects.count > 1 {
			nothingTextField?.isHidden = true
			multipleTextField?.isHidden = false
		}
		else {
			nothingTextField?.isHidden = false
			multipleTextField?.isHidden = true
		}
	}
}
