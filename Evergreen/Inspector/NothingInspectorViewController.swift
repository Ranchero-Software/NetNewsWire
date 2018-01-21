//
//  NothingInspectorViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

final class NothingInspectorViewController: NSViewController, Inspector {

	let isFallbackInspector = true
	var objects: [Any]?

	func canInspect(_ objects: [Any]) -> Bool {

		return true
	}

	func willEndInspectingObjects() {

	}
}
