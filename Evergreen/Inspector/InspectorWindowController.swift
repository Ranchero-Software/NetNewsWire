//
//  InspectorWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

protocol Inspector {

	var objects: [Any] { get set }

	func isInspectorFor(_ objects: [Any]) -> Bool
}

final class InspectorWindowController: NSWindowController {

	public var isOpen: Bool {
		get {
			return isWindowLoaded && window!.isVisible
		}
	}

	func inspector(for objects: [Any]) -> Inspector {

		
	}
}
