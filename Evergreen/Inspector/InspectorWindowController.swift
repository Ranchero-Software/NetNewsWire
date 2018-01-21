//
//  InspectorWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

final class InspectorWindowController: NSWindowController {

	public var isOpen: Bool {
		get {
			return isWindowLoaded && window!.isVisible
		}
	}

}
