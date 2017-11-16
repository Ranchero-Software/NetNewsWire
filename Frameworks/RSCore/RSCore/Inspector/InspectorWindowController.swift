//
//  InspectorWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa

public class InspectorWindowController: NSWindowController {

	public var isOpen: Bool {
		get {
			return isWindowLoaded && window!.isVisible
		}
	}

	public convenience init() {

		self.init(windowNibName: NSNib.Name(rawValue: "InspectorWindow"))
	}
}
