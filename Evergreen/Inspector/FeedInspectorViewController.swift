//
//  FeedInspectorViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Data

final class FeedInspectorViewController: NSViewController, Inspector {

	let isFallbackInspector = false
	var objects: [Any]?

	func canInspect(_ objects: [Any]) -> Bool {

		return objects.count == 1 && objects.first is Feed
	}

	func willEndInspectingObjects() {

	}
}
